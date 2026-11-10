# agent-shell-browser

Send a browser selection or a whole page into a running
[agent-shell](https://github.com/xenodium/agent-shell) session. Right-click,
pick a session from a popup (most recently used first), optionally add an
instruction, then stage it in the prompt or send and submit.

```
browser extension --native messaging--> host/agent_shell_browser_host.py
                                          --emacsclient--> agent-shell-browser-dispatch
```

Works in Chrome and other Chromium browsers, and Firefox 128+.

## Install

1. Emacs: make sure `server-start` runs, then load the package.

   ```elisp
   (use-package agent-shell-browser
     :load-path "~/opt/agent-shell-browser"
     :demand t)
   ```

2. Native messaging host (macOS and Linux):

       ./install.sh

   This writes a launcher to `~/.local/share/agent-shell-browser/host` and
   registers it with every Chromium-family browser and Firefox it finds. It
   records the absolute path of `emacsclient` and `python3`, because browsers
   start the host with a bare `PATH`. If your server doesn't use the default
   socket, pass `--socket NAME`. To remove everything, run `--uninstall`.

3. Extension:
   - Chrome: `chrome://extensions` → Developer mode → Load unpacked →
     `extension/`. The `key` in `manifest.json` pins the id to
     `hofnfmddfbgnkmkamefcgopabhcpnjlo`, which `install.sh` allows.
   - Firefox: `make firefox`, then `about:debugging` → This Firefox → Load
     Temporary Add-on → `build/firefox/manifest.json`. Firefox needs
     `background.scripts`, which Chrome rejects in MV3.

## Use

- Right-click a selection → **Send selection to agent-shell…**
- Right-click the page → **Send page to agent-shell…** (Readability + Turndown
  markdown)
- Toolbar button: sends the selection if there is one, otherwise the page

In the picker:

```
C-n / C-p, arrows    move between sessions
Enter, Cmd/Ctrl-Enter    stage into the prompt
Shift-Cmd/Ctrl-Enter     send and submit (queued if the session is busy)
Esc                      close
```

The captured content can be edited under the "characters (edit)" toggle.
If you stage into a session that is mid-turn and has no live prompt, the
text goes in when the turn finishes.

## Customize

```
agent-shell-browser-format-function   request alist -> prompt text
agent-shell-browser-session-functions buffer -> extra picker fields
agent-shell-browser-raise-frame       focus Emacs after staging
```

The picker shows a session's `description` and `detail` fields when they
are present. Add them with `agent-shell-browser-session-functions`.

### agent-shell-dashboard summaries

`agent-shell-browser-dashboard.el` fills `description` and `detail` from
[agent-shell-dashboard](https://github.com/gempesaw/agent-shell-dashboard)
summaries. It's optional:

```elisp
(use-package agent-shell-browser-dashboard
  :load-path "~/opt/agent-shell-browser"
  :after (agent-shell-browser agent-shell-dashboard)
  :config (agent-shell-browser-dashboard-mode 1))
```

## Development

    make compile test

Vendored, unmodified: `extension/vendor/Readability.js` (@mozilla/readability
0.6.0, Apache-2.0) and `extension/vendor/turndown.js` (turndown 7.2.5, MIT).
