# GitHub Inbox for Omarchy

Your GitHub inbox in the [Omarchy](https://omarchy.org) bar: one chip with
your open workload count, one panel with everything on your plate. Every row
is one click (or one keystroke) away from its page on GitHub.

<img src="screenshot.png" width="415" alt="GitHub Inbox panel under the Omarchy bar, showing the org filter, fuzzy find, and the six sections">

## Sections

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

The bar chip shows the octocat plus your open PR + review + issue count, and
switches to the urgent color while unread notifications or mentions wait.

## Interactions

| Input | Action |
|---|---|
| Left-click chip | Toggle the panel |
| Middle-click chip | Refresh |
| Right-click chip | Open github.com/notifications |
| `j`/`k` or ↓/↑ | Move the row cursor |
| `h`/`l` or ←/→ | Switch organization filter |
| `[` / `]` | Jump between sections |
| `Enter` | Open the selected row as a standalone app window |
| `/` | Fuzzy find (neovim-style subsequence match on titles, repos, and section names, scoped to the active org filter); `Enter` accepts the filter and returns to navigation, `Esc` clears |
| `r` | Refresh |

IPC works from anywhere, always targeting the focused monitor's instance:

```bash
omarchy-shell viniciusfnery.github-inbox toggle   # or: open, close, refresh
omarchy-shell viniciusfnery.github-inbox find     # open with fuzzy find focused
```

A keybinding, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + G", "GitHub Inbox", "omarchy-shell viniciusfnery.github-inbox find")
```

## Install

Requires the [GitHub CLI](https://cli.github.com) (`gh`) and `jq`
(preinstalled on Omarchy):

```bash
omarchy pkg add github-cli   # if gh is missing
omarchy plugin add https://github.com/viniciusfnery/omarchy-github-inbox.git --enable
```

## Authentication

The plugin rides the GitHub CLI's login. It never sees or stores a token
itself. Sign in once:

```bash
gh auth login
```

Pick **GitHub.com → HTTPS → Login with a web browser** and follow the device
prompt; the token lands in your system keyring. Verify with `gh auth status`.
The default scopes gh requests (`repo`, `read:org`) cover everything the
plugin reads, including the notifications API. Until you sign in (or whenever
the token expires), the panel shows a "Not signed in: run gh auth login" card
instead of silently going empty, and recovers on its own within
30 seconds of you logging in.

## Opening links

Every row (and the notifications page on the chip) opens as a **standalone app
window**: no tab strip, no address bar, just the page, the way a PWA looks.
Each click opens its own window, and the new window is focused for you instead
of landing behind whatever you were working in.

The window comes from **your** default browser, resolved the same way Omarchy
resolves it (`xdg-settings`, then the MIME handler). Chromium-family browsers
(Chrome, Chromium, Brave, Edge, Vivaldi) get the app window; browsers without
an equivalent (Firefox and its forks) fall back to an ordinary window, as does
the `openMode: browser` setting below.

App windows are named after the site by the browser itself
(`brave-github.com__notifications-Default`,
`chrome-github.com__owner__repo__pull__12-Default`), which is what lets
Hyprland style them apart from your browser window. To get the floating,
centered, fixed-size window a PWA usually has, add this to
`~/.config/hypr/windows.lua` and `require("hypr.windows")` from your
`~/.config/hypr/hyprland.lua`:

```lua
o.window("^.+\\-github\\.com__.+$", { float = true, center = true, size = { 1280, 900 } })
```

Hyprland matches rule regexes against the whole window class, hence the
anchors. Without that rule the window just tiles like any other window.

Which path a click took is recorded in
`~/.cache/omarchy-github-inbox-open.log` (one line, capped at 256KB), so "it
opened the wrong window" is a log read rather than a guess.

### If links still open the old way

Start with that log: an empty file after a click means the panel did not run
`open.sh` at all, which in practice means the shell is still running the old
plugin. Quickshell hot-reloads plugins on change, but a shell that has been
running since a plugin was edited can keep the old instance alive; restart it:

```bash
pkill -f 'quickshell -n -p /usr/share/omarchy/shell'   # Omarchy relaunches it
```

## Settings

Settings live in the widget's entry in `~/.config/omarchy/shell.json`. Edit
that file directly (it hot-reloads on save), or set values from the terminal:

```bash
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

## Uninstall

```bash
omarchy plugin remove viniciusfnery.github-inbox
```

That unloads the widget from the bar and deletes the plugin. It runs no
background services, so nothing else keeps running. For a full scrub, two
small data files remain to delete, and your keybinding if you added one:

```bash
rm -f ~/.cache/omarchy-github-tasks.json \
      ~/.cache/omarchy-github-inbox-open.log \
      ~/.local/state/omarchy/github-mentions-seen.json
```

The plugin never touches your GitHub credentials; those belong to the
`gh` CLI (`gh auth logout` if you want them gone too).

## Development

`fetch.sh` (the data collector) and `open.sh` (the link opener) are covered by
a token-free test suite that runs them against a fake `gh` serving fixtures and
a fake browser recording launches, including regression tests for rate-limit
garbage on stdout, oversized payloads, and cache poisoning:

```bash
tests/run.sh
```

CI runs the suite plus shellcheck and a manifest sanity check on every push.

## Notes on behavior

- Auth rides the `gh` CLI's login; a signed-out or offline state shows an
  error card while the last good data stays visible, retrying every 30s.
- Results are cached for 60s (`~/.cache/omarchy-github-tasks.json`) so
  multi-monitor bars share one API burst; a cold refresh makes ~8 requests,
  well inside GitHub's rate limits.
- Mention read-state is local (`~/.local/state/omarchy/github-mentions-seen.json`);
  after suspend/resume the panel detects the time jump and refreshes within a
  minute.
- Lists cap at the 50 most recently updated per section (mentions 30, closed
  20 per type / last 30 days).
- Rows only ever open `https://github.com/` URLs; GitHub Enterprise hosts are
  not supported. `open.sh` re-checks that allowlist itself before launching
  anything, so a poisoned cache cannot open a different host or inject flags.

## License

MIT
