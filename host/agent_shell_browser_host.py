#!/usr/bin/env python3
import json
import os
import struct
import subprocess
import sys
import tempfile

EMACSCLIENT = os.environ.get("AGENT_SHELL_BROWSER_EMACSCLIENT") or "emacsclient"
SOCKET = os.environ.get("AGENT_SHELL_BROWSER_SOCKET")
TIMEOUT = float(os.environ.get("AGENT_SHELL_BROWSER_TIMEOUT", "15"))


def read_message():
    header = sys.stdin.buffer.read(4)
    if len(header) < 4:
        return None

    (length,) = struct.unpack("@I", header)
    return json.loads(sys.stdin.buffer.read(length).decode("utf-8"))


def write_message(obj):
    data = json.dumps(obj).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("@I", len(data)) + data)
    sys.stdout.buffer.flush()


def elisp_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def call_emacs(request):
    with tempfile.TemporaryDirectory(prefix="agent-shell-browser-") as tmp:
        request_file = os.path.join(tmp, "request.json")
        response_file = os.path.join(tmp, "response.json")
        with open(request_file, "w", encoding="utf-8") as f:
            json.dump(request, f)

        form = "(progn (require 'agent-shell-browser) (agent-shell-browser-dispatch {} {}))".format(
            elisp_string(request_file), elisp_string(response_file)
        )
        cmd = [EMACSCLIENT]
        if SOCKET:
            cmd += ["--socket-name", SOCKET]
        cmd += ["--eval", form]

        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
        except FileNotFoundError:
            return {"ok": False, "error": f"emacsclient not found: {EMACSCLIENT}"}
        except subprocess.TimeoutExpired:
            return {"ok": False, "error": f"Emacs did not answer within {TIMEOUT:g}s"}

        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            return {"ok": False, "error": detail or f"emacsclient exited {proc.returncode}"}

        try:
            with open(response_file, encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError) as e:
            return {"ok": False, "error": f"No usable response from Emacs: {e}"}


def main():
    while True:
        request = read_message()
        if request is None:
            return
        write_message(call_emacs(request))


if __name__ == "__main__":
    main()
