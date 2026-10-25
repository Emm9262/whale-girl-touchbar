#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
app_path="$project_dir/build/DSH 鲸鱼娘.app"
destination_dir="$HOME/Applications"
dry_run=false
usage() { printf '%s\n' 'Usage: scripts/install.sh [--app PATH] [--destination-dir DIR] [--dry-run]' 'Copies the app without launching it or enabling login startup.' 'An existing copy with the same bundle ID is moved to a dated backup.'; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --app) [ "$#" -ge 2 ] || exit 2; app_path="$2"; shift ;;
    --destination-dir) [ "$#" -ge 2 ] || exit 2; destination_dir="$2"; shift ;;
    --dry-run) dry_run=true ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
target="$destination_dir/DSH 鲸鱼娘.app"
if "$dry_run"; then printf 'Would install %s to %s; no launch or auto-start\n' "$app_path" "$target"; exit 0; fi
[ -d "$app_path" ] && [ ! -L "$app_path" ] || { printf 'App directory is missing or is a symlink\n' >&2; exit 1; }
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
[ "$identifier" = org.whalegirl.touchbar ] || { printf 'Unexpected app bundle identifier\n' >&2; exit 1; }
/usr/bin/codesign --verify --deep --strict "$app_path"
mkdir -p "$destination_dir"
source_real=$(cd "$app_path" && pwd -P)
target_parent=$(cd "$destination_dir" && pwd -P)
[ "$source_real" != "$target_parent/DSH 鲸鱼娘.app" ] || { printf 'Source app is already at the destination\n' >&2; exit 1; }
[ ! -L "$target" ] || { printf 'Refusing a symlink destination\n' >&2; exit 1; }
if [ -e "$target" ]; then
  installed_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist")
  [ "$installed_id" = org.whalegirl.touchbar ] || { printf 'Destination is a different app; choose another directory\n' >&2; exit 1; }
  backup="$destination_dir/DSH 鲸鱼娘.backup-$(date +%Y%m%d-%H%M%S)-$$.app"
  [ ! -e "$backup" ] || exit 1
  /bin/mv "$target" "$backup"
  printf 'Previous app backed up at %s\n' "$backup"
fi
/usr/bin/ditto "$app_path" "$target"
/usr/bin/codesign --verify --deep --strict "$target"
printf 'Installed: %s\n' "$target"
printf '%s\n' 'Open the app yourself. Login startup remains unchanged.'
