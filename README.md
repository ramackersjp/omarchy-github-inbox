# GitHub Inbox for Omarchy

Your GitHub inbox in the [Omarchy](https://omarchy.org) bar: one chip with
your open workload count, one panel with everything on your plate. Every row
is one click (or one keystroke) away from its page on GitHub.

<img src="screenshot.png" width="415" alt="GitHub Inbox panel under the Omarchy bar, showing the org filter, fuzzy find, and the six sections">

## Install

```sh
omarchy plugin add https://github.com/ramackersjp/omarchy-github-inbox.git --enable
```

Sign in once with the GitHub CLI, which is where the plugin gets its access:

```sh
gh auth login
```

Pick **GitHub.com -> HTTPS -> Login with a web browser** and follow the device
prompt; the token lands in your system keyring. Verify with `gh auth status`.
The default scopes gh requests (`repo`, `read:org`) cover everything the
plugin reads, including the notifications API. Until you sign in, or whenever
the token expires, the panel shows a "Not signed in: run gh auth login" card
instead of silently going empty, and recovers on its own within 30 seconds of
you logging in.

This repository is a fork of
[viniciusfnery/omarchy-github-inbox](https://github.com/viniciusfnery/omarchy-github-inbox),
which stays the place for the original author's releases. Install from this
fork if you want the standalone app windows described under
[Opening links](#opening-links); `main` here can carry work the upstream does
not have yet. The plugin id stays `viniciusfnery.github-inbox` in both, so
every command below works either way.

## Requirements

| Requirement | Needed for | Missing it means |
|---|---|---|
| [GitHub CLI](https://cli.github.com) (`gh`) | every API call, and the login the plugin rides | panel shows a "Not signed in" card |
| `jq` | parsing API replies | install `omarchy pkg add jq` |
| `xdg-utils` (`xdg-settings`, `xdg-mime`) | finding your default browser for link opening | falls back to `omarchy-launch-browser` |
| `coreutils` (`date`, `stat`, `mkdir`, `comm`, `sed`, `timeout`) | the fetch and link scripts | those scripts fail |
| `systemd` user session plus `uwsm` | launching the browser outside the shell's scope | the browser is started directly instead |
| Hyprland with `hyprctl` and `jq` | focusing the new app window for you | the window opens but keeps its own focus |
| A Chromium-family browser | the PWA-shaped app window | Firefox and forks get an ordinary window |

`gh` and `jq` come with Omarchy. Everything else is standard on an Omarchy
install, and no extra package is pulled in by the plugin itself.

## Usage

Click the chip in the bar to open the panel, click a row to open it. The chip
shows the octocat plus your open PR, review, and issue count, and switches to
the urgent color while unread notifications or mentions wait.

### What the panel shows

- **Notifications**: your unread GitHub notifications, minus anything another
  section already represents; clicking a row dismisses it here *and* marks the
  thread read on GitHub
- **Pull requests**: open PRs you authored or are assigned to (drafts dimmed)
- **Review requests**: open PRs where your review was requested
- **Issues**: open issues assigned to you
- **Mentions**: the last 30 open threads you were mentioned in, with an
  unread dot that only lights up when *someone else* acts (your own comments
  and reactions never re-mark a thread) and clears when you open it
- **Recently closed**: the 5 most recent closures (last 30 days) among your
  PRs, assigned issues, and mention threads, per org tab

### Interactions

| Input | Action |
|---|---|
| Left-click chip | Toggle the panel |
| Middle-click chip | Refresh |
| Right-click chip | Open github.com/notifications |
| `j`/`k` or down/up | Move the row cursor |
| `h`/`l` or left/right | Switch organization filter |
| `[` / `]` | Jump between sections |
| `Enter` | Open the selected row as a standalone app window |
| `/` | Fuzzy find (neovim-style subsequence match on titles, repos, and section names, scoped to the active org filter); `Enter` accepts the filter and returns to navigation, `Esc` clears |
| `r` | Refresh |
| `Esc` | Close the panel |

IPC works from anywhere and always targets the focused monitor's instance:

```sh
omarchy-shell viniciusfnery.github-inbox toggle   # or: open, close, refresh
omarchy-shell viniciusfnery.github-inbox find     # open with fuzzy find focused
```

A keybinding, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + G", "GitHub Inbox", "omarchy-shell viniciusfnery.github-inbox find")
```

### Opening links

Every row, and the notifications page on the chip, opens as a **standalone app
window**: no tab strip, no address bar, just the page, the way a PWA looks.
Each click opens its own window, and the new window is focused for you instead
of landing behind whatever you were working in.

The window comes from **your** default browser, resolved the same way Omarchy
resolves it (`xdg-settings`, then the MIME handler). Chromium-family browsers
(Chrome, Chromium, Brave, Edge, Vivaldi) get the app window even when no web
app is installed; browsers without an equivalent (Firefox and its forks) fall
back to an ordinary window, as does the `openMode: browser` setting below.

App windows are named after the site by the browser itself
(`brave-github.com__notifications-Default`,
`chrome-github.com__owner__repo__pull__12-Default`), which is what lets
Hyprland style them apart from your browser window.

## Configure

### Settings

Settings live in the widget's entry in `~/.config/omarchy/shell.json`. Edit
that file directly (it hot-reloads on save), or set values from the terminal:

```sh
omarchy bar set viniciusfnery.github-inbox refreshIntervalSec 600 --json
omarchy bar set viniciusfnery.github-inbox mentionLimit 50 --json
```

(`--json` keeps numbers as numbers.) They also appear in the Omarchy
settings UI under the bar widget's options.

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `300` | How often the GitHub data refreshes (min 60) |
| `mentionLimit` | `30` | How many open mention threads to track |
| `closedDays` | `30` | How far back "recently closed" looks |
| `closedLimit` | `5` | Closed rows shown per org tab |
| `openMode` | `app` | `app` opens links as standalone windows, `browser` opens an ordinary browser window |

### Where the chip sits

```sh
omarchy bar move viniciusfnery.github-inbox --section center --index 0
```

Sections are `left`, `center`, and `right`. Omit `--index` to let Omarchy
place it.

### A floating, centered app window

The Hyprland rule below gives the app window the shape a PWA usually has,
floating and centered at a fixed size. Without it the window just tiles like
any other window. Add it to `~/.config/hypr/windows.lua`, and
`require("hypr.windows")` from `~/.config/hypr/hyprland.lua`:

```lua
o.window("^.+\\-github\\.com__.+$", { float = true, center = true, size = { 1280, 900 } })
```

Hyprland matches rule regexes against the whole window class, hence the
anchors. This is a Hyprland-only nicety; the plugin itself has no compositor
dependency beyond using `hyprctl` to focus the window.

### Deciding what a click did

Which path a click took is recorded in
`~/.cache/omarchy-github-inbox-open.log`, one line per click, capped at
256KB, so "it opened the wrong window" is a log read instead of a guess:

```sh
tail -5 ~/.cache/omarchy-github-inbox-open.log
```

```
2026-09-30T16:51:42+0200 called: mode=app url=https://github.com/owner/repo/pull/2
2026-09-30T16:51:42+0200 app window: brave-origin --app=https://github.com/owner/repo/pull/2
2026-09-30T16:51:42+0200 focused the new app window (brave-github.com__owner_repo_pull_2-Default)
```

## Remove

```sh
omarchy plugin remove viniciusfnery.github-inbox
```

That unloads the widget from the bar and deletes the plugin. It runs no
background services, so nothing else keeps running. For a full scrub, delete
the small data files it wrote, plus your keybinding if you added one:

```sh
rm -f ~/.cache/omarchy-github-tasks.json \
      ~/.cache/omarchy-github-inbox-open.log \
      ~/.local/state/omarchy/github-mentions-seen.json
```

The plugin never touches your GitHub credentials; those belong to the `gh`
CLI (`gh auth logout` if you want them gone too).

## Security and network access

- Runs as your own user, with your own permissions. It never asks for `sudo`,
  installs nothing, and starts no service, daemon, or second Quickshell
  process.
- The only network traffic is to `api.github.com`, and only through the `gh`
  CLI. The plugin never sees, stores, or logs a token.
- Rows only ever open `https://github.com/` URLs; GitHub Enterprise hosts are
  not supported. `open.sh` re-checks that allowlist itself before launching
  anything, so a poisoned cache cannot open a different host or inject flags.
- Files written: `~/.cache/omarchy-github-tasks.json`,
  `~/.cache/omarchy-github-inbox-open.log`,
  `~/.local/state/omarchy/github-mentions-seen.json`, and the widget's own
  settings entry in `~/.config/omarchy/shell.json`.

## Troubleshooting

**Links open in the browser window instead of as an app window.** Read
`~/.cache/omarchy-github-inbox-open.log`. An empty file after a click means the
panel did not run `open.sh` at all, which in practice means the shell is still
running the old plugin: Quickshell hot-reloads plugins on change, but a shell
that has been running since a plugin was edited can keep the old instance
alive. Restart it, Omarchy relaunches it by itself:

```sh
pkill -f 'quickshell -n -p /usr/share/omarchy/shell'
```

**The plugin validates but is not listed.** Then it is not enabled:

```sh
omarchy-shell shell rescanPlugins
omarchy plugin list --json | jq --arg id viniciusfnery.github-inbox '.[] | select(.id == $id)'
```

**The plugin is listed but the chip is missing, or the panel stays empty.**
Look for QML errors:

```sh
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

**The panel shows nothing useful.** `gh auth status` first, then press `r` for
a forced refresh. A signed-out or offline state keeps the last good data
visible and retries every 30 seconds.

## Notes on behavior

- Results are cached for 60s (`~/.cache/omarchy-github-tasks.json`) so
  multi-monitor bars share one API burst; a cold refresh makes about 8
  requests, well inside GitHub's rate limits.
- Mention read-state is local
  (`~/.local/state/omarchy/github-mentions-seen.json`); after suspend or
  resume the panel detects the time jump and refreshes within a minute.
- Lists cap at the 50 most recently updated per section (mentions 30, closed
  20 per type over the last 30 days).

## Development

`fetch.sh` (the data collector) and `open.sh` (the link opener) are covered by
a token-free test suite that runs them against a fake `gh` serving fixtures and
fake browser, XDG, systemd, and Hyprland commands recording launches,
including regression tests for rate-limit garbage on stdout, oversized
payloads, and cache poisoning:

```sh
tests/run.sh
```

CI runs the suite plus shellcheck and a manifest sanity check on every push.

Validate a checkout the way Omarchy does, without running it:

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/viniciusfnery.github-inbox"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/Panel.qml"
```

Both must exit without an error.

### OpenCode reviews pull requests

`.github/workflows/opencode-review.yml` follows the upstream guide at
<https://opencode.ai/docs/github/>. It reviews every pull request on opened,
synchronized, reopened, and ready-for-review, and skips PRs whose head lives in
another repository, plus anything authored by a bot, so a fork's head cannot
steer the prompt.

It needs one repository secret, the API key for the model below:

```sh
gh secret set OPENCODE_API_KEY --repo ramackersjp/omarchy-github-inbox
```

Change the `model` input, and the matching key, if you review with a
different provider. Both actions are pinned by commit, the way `ci.yml` pins
`actions/checkout`. The opencode binary itself is not pinned: the action
installs it on the runner at run time.

The workflow uses `use_github_token`, which skips installing the OpenCode
GitHub App and stands the runner token in for it. That makes the permissions in
the job deliberate rather than inherited: `contents: read`,
`pull-requests: write`, `issues: write`. Note the missing `contents: write`: a
review bot that cannot push cannot push, whatever the prompt asks of it. The
prompt asks for review comments only, so an edit is refused by the token rather
than by good manners.

## License

MIT, as in the upstream this is forked from. Copyright (c) 2026 Vinicius Nery.
