#!/bin/bash
# Opens a github.com URL in the user's default browser as a standalone app
# window: no tab strip, no omnibox, just the page, the same shape a PWA has.
# Every row in the panel (and the notifications page on the chip) goes through
# here.
#
# Usage: open.sh [--mode app|browser] <github-url>
set -uo pipefail

# WM_CLASS prefix Chromium-family browsers put on every `--app=` window, e.g.
# brave-github.com__notifications-Default. Used only to tell our own window
# apart from the rest; the browser owns this name, not us.
readonly app_class_pattern='.+\-github\.com__.+'

mode="app"
while (( $# > 0 )); do
  case "$1" in
  --mode)
    mode="${2:-app}"
    shift 2 || true
    ;;
  *) break ;;
  esac
done

url="${1:-}"

# One line per open, so "it opened the wrong thing" is answerable after the
# fact instead of by guessing. The path is predictable and user-writable: skip
# a planted FIFO or symlink rather than block on it or write through it.
log_file="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-github-inbox-open.log"
log() {
  local f="$log_file"
  [[ -p $f || -L $f ]] && return 0
  mkdir -p "$(dirname "$f")" 2>/dev/null || return 0
  (( $(stat -c %s "$f" 2>/dev/null || echo 0) <= 262144 )) || : >"$f"
  # Newlines would forge extra log lines, so they never reach the file.
  printf '%s %s\n' "$(date +%FT%T%z)" "${*//$'\n'/ }" >>"$f" 2>/dev/null || true
}

# The one line that matters most: the panel did run this script at all.
log "called: mode=$mode url=${url:-<none>}"

# Only github.com ever reaches a browser, and only characters that cannot
# escape the caller's single quoting or the browser flags: a poisoned cache
# must not be able to open anything else. (Bash needs the pattern in a
# variable: an unquoted literal with `&` in it does not parse.)
readonly url_pattern='^https://github\.com/[A-Za-z0-9._~:/?#@!$%&*+=,-]+$'
if [[ ! $url =~ $url_pattern ]]; then
  log "rejected: not a github.com URL this plugin opens"
  exit 1
fi
# Anything but an explicit "browser" means app mode.
[[ $mode == "browser" ]] || mode="app"

# Detached like omarchy-launch-browser: uwsm scoping when available, plain
# background start when this session has no user systemd.
launch() {
  if command -v systemd-run >/dev/null && command -v uwsm-app >/dev/null; then
    systemd-run --user --quiet --collect --unit="github-inbox-$(date +%s%N)" \
      --property=StandardOutput=null --property=StandardError=null \
      uwsm-app -- "$@" && return 0
    log "launch failed for: $*"
    return 1
  fi
  "$@" &
}

# Hyprland 0.55 and newer take lua expressions; older builds take the classic
# dispatcher string. Try the new one first and fall back.
focus_address() {
  hyprctl --quiet dispatch "hl.dsp.focus({ window = \"address:$1\" })" >/dev/null 2>&1 \
    || hyprctl --quiet dispatch focuswindow "address:$1" >/dev/null 2>&1
}

# The panel sits in the bar, so a new window would otherwise land behind
# whatever the user is working in. The class in the snapshot is what tells our
# window apart from any other that happens to open while we poll.
focus_new_window() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { log "no hyprland session; window not focused"; return 0; }
  command -v hyprctl >/dev/null || { log "no hyprctl; window not focused"; return 0; }
  command -v jq >/dev/null || { log "no jq; window not focused"; return 0; }

  local before now class new
  before=$(hyprctl -j clients 2>/dev/null | jq -r '.[].address' | sort)
  for _ in {1..30}; do
    sleep 0.1
    now=$(hyprctl -j clients 2>/dev/null | jq -r '.[].address' | sort)
    new=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$now") | head -1)
    [[ -n $new ]] || continue
    class=$(hyprctl -j clients 2>/dev/null \
      | jq -r --arg a "$new" '.[] | select(.address == $a) | .class')
    [[ $class =~ $app_class_pattern ]] || continue
    focus_address "$new"
    log "focused the new app window ($class)"
    return 0
  done
  # The window opened but stayed behind whatever had focus, which reads as "it
  # opened in the browser"; say so instead of failing silently.
  log "no window matched $app_class_pattern within 3s; the app window stayed behind"
}

# Same resolution order as omarchy-launch-browser: xdg-settings first, the
# MIME default as a fallback, then the first Exec token of that desktop entry.
default_browser=$(env -u BROWSER xdg-settings get default-web-browser 2>/dev/null)
[[ -n $default_browser ]] || default_browser=$(xdg-mime query default x-scheme-handler/https 2>/dev/null)

browser_exec=""
if [[ $default_browser =~ ^[A-Za-z0-9._+-]+\.desktop$ ]]; then
  for dir in "$HOME/.local/share/applications" "$HOME/.nix-profile/share/applications" /usr/share/applications; do
    desktop_file="$dir/$default_browser"
    [[ -f $desktop_file && ! -L $desktop_file ]] || continue
    browser_exec=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop_file" 2>/dev/null | head -1)
    [[ -n $browser_exec ]] && break
  done
fi

# Unresolvable (no desktop entry, or a wrapper like flatpak-snap whose Exec
# isn't the browser itself): hand the URL to Omarchy's own launcher.
if [[ -z $browser_exec ]]; then
  log "no browser from desktop entry (${default_browser:-none}); omarchy-launch-browser $url"
  launch omarchy-launch-browser "$url"
  exit 0
fi

# Chromium-family browsers all understand `--app=`; Firefox and its forks
# have no equivalent, so they get an ordinary window rather than a broken flag.
browser_version=$(timeout 5 "$browser_exec" --version 2>/dev/null | head -1)
supports_app_mode() { [[ ${browser_version,,} =~ (chromium|chrome|brave|vivaldi|edge) ]]; }

if [[ $mode == "browser" ]]; then
  log "browser mode: $browser_exec $url"
  launch "$browser_exec" "$url"
elif ! supports_app_mode; then
  log "no app mode in ${browser_version:-<no version>}: $browser_exec $url"
  launch "$browser_exec" "$url"
else
  log "app window: $browser_exec --app=$url"
  launch "$browser_exec" "--app=$url"
  focus_new_window
fi