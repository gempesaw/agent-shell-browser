#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [--emacsclient PATH] [--socket NAME] [--extension-id ID]... [--uninstall]

Registers the agent_shell_browser native messaging host for every
Chromium-family browser and Firefox found on this machine.

  --emacsclient PATH   emacsclient to call (default: first on PATH)
  --socket NAME        Emacs server socket name or path (default: emacsclient's)
  --extension-id ID    Allow another Chromium extension id, e.g. a Web Store
                       install.  The unpacked id from manifest.json is always
                       allowed.
  --uninstall          Remove the host manifests and launcher
EOF
}

name=agent_shell_browser
repo=$(cd "$(dirname "$0")" && pwd)
data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/agent-shell-browser
launcher=$data_dir/host
emacsclient=$(command -v emacsclient || true)
socket=
uninstall=
extra_ids=()

while [ $# -gt 0 ]; do
    case $1 in
        --emacsclient) emacsclient=$2; shift 2 ;;
        --socket) socket=$2; shift 2 ;;
        --extension-id) extra_ids+=("$2"); shift 2 ;;
        --uninstall) uninstall=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

case $(uname -s) in
    Darwin)
        base="$HOME/Library/Application Support"
        chromium_dirs=("Google/Chrome" "Google/Chrome Beta" "Google/Chrome Canary"
                       "Chromium" "BraveSoftware/Brave-Browser" "Microsoft Edge"
                       "Vivaldi")
        firefox_dir="$base/Mozilla/NativeMessagingHosts"
        firefox_marker="$base/Firefox"
        ;;
    Linux)
        base="${XDG_CONFIG_HOME:-$HOME/.config}"
        chromium_dirs=("google-chrome" "google-chrome-beta" "google-chrome-unstable"
                       "chromium" "BraveSoftware/Brave-Browser" "microsoft-edge"
                       "vivaldi")
        firefox_dir="$HOME/.mozilla/native-messaging-hosts"
        firefox_marker="$HOME/.mozilla"
        ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

targets=()
for dir in "${chromium_dirs[@]}"; do
    [ -d "$base/$dir" ] && targets+=("chromium:$base/$dir/NativeMessagingHosts")
done
[ -d "$firefox_marker" ] && targets+=("firefox:$firefox_dir")

if [ -n "$uninstall" ]; then
    for target in "${targets[@]}"; do
        rm -fv "${target#*:}/$name.json"
    done
    rm -fv "$launcher"
    exit 0
fi

if [ ${#targets[@]} -eq 0 ]; then
    echo "No supported browser profile directories found." >&2
    exit 1
fi

if [ -z "$emacsclient" ]; then
    echo "emacsclient not found on PATH; pass --emacsclient." >&2
    exit 1
fi

python=$(python3 -c 'import sys; print(sys.executable)')
read -r extension_id gecko_id < <("$python" - "$repo/extension/manifest.json" <<'EOF'
import base64, hashlib, json, sys
manifest = json.load(open(sys.argv[1]))
digest = hashlib.sha256(base64.b64decode(manifest["key"])).hexdigest()[:32]
print("".join(chr(ord("a") + int(c, 16)) for c in digest),
      manifest["browser_specific_settings"]["gecko"]["id"])
EOF
)

mkdir -p "$data_dir"
{
    echo '#!/bin/bash'
    printf 'export AGENT_SHELL_BROWSER_EMACSCLIENT=%q\n' "$emacsclient"
    [ -n "$socket" ] && printf 'export AGENT_SHELL_BROWSER_SOCKET=%q\n' "$socket"
    printf 'exec %q %q "$@"\n' "$python" "$repo/host/agent_shell_browser_host.py"
} > "$launcher"
chmod +x "$launcher"

origins=$("$python" -c 'import json, sys; print(json.dumps(["chrome-extension://%s/" % i for i in sys.argv[1:]]))' \
    "$extension_id" "${extra_ids[@]+"${extra_ids[@]}"}")

for target in "${targets[@]}"; do
    kind=${target%%:*}
    dir=${target#*:}
    mkdir -p "$dir"
    if [ "$kind" = chromium ]; then
        allowed="\"allowed_origins\": $origins"
    else
        allowed="\"allowed_extensions\": [\"$gecko_id\"]"
    fi
    cat > "$dir/$name.json" <<EOF
{
  "name": "$name",
  "description": "Send browser content to agent-shell sessions in Emacs",
  "path": "$launcher",
  "type": "stdio",
  $allowed
}
EOF
    echo "Installed $dir/$name.json"
done

echo "Launcher: $launcher"
echo "Chromium extension id: $extension_id"
