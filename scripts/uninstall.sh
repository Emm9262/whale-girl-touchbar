#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
app_path="$HOME/Applications/DSH 鲸鱼娘.app"
dry_run=false
usage() { printf '%s\n' 'Usage: scripts/uninstall.sh [--app PATH] [--dry-run]' 'Moves this app to Trash and disables only its login startup.' 'Preferences, user data, DSH and the optional DSH bridge are preserved.'; }
while [ "$#" -gt 0 ]; do
  case "$1" in --help|-h) usage; exit 0 ;; --app) [ "$#" -ge 2 ] || exit 2; app_path="$2"; shift ;; --dry-run) dry_run=true ;; *) usage >&2; exit 2 ;; esac
  shift
done
if "$dry_run"; then printf 'Would disable this app’s login startup and move %s to Trash; user data and DSH remain\n' "$app_path"; exit 0; fi
[ -d "$app_path" ] && [ ! -L "$app_path" ] || { printf 'App directory is missing or is a symlink\n' >&2; exit 1; }
[ "$(basename "$app_path")" = 'DSH 鲸鱼娘.app' ] || { printf 'Unexpected app directory name\n' >&2; exit 1; }
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
[ "$identifier" = org.whalegirl.touchbar ] || { printf 'Refusing to remove a different app\n' >&2; exit 1; }
bash "$project_dir/scripts/autostart.sh" disable
"$app_path/Contents/MacOS/DSHWhale" --quit
trash_dir="$HOME/.Trash"
mkdir -p "$trash_dir"
trash_path="$trash_dir/DSH 鲸鱼娘-$(date +%Y%m%d-%H%M%S)-$$.app"
[ ! -e "$trash_path" ] || exit 1
/bin/mv "$app_path" "$trash_path"
printf 'Moved app to Trash: %s\n' "$trash_path"
printf '%s\n' 'User data and DSH bridge remain. Remove the bridge separately through its own documented command.'
