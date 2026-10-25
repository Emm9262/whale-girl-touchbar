#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
app_path="$project_dir/build/DSH 鲸鱼娘.app"
output_dir="$project_dir/dist"
dry_run=false
usage() { cat <<'HELP'
Usage: scripts/package.sh [--app PATH] [--output DIR] [--dry-run]
Creates a ZIP, checksum and distribution status. Does not publish or install.
Optional SIGN_IDENTITY signs a staged copy with Developer ID.
Optional NOTARY_PROFILE uses a preconfigured notarytool keychain profile;
this requires SIGN_IDENTITY. Signing credentials are never read from files.
HELP
}
while [ "$#" -gt 0 ]; do
  case "$1" in --help|-h) usage; exit 0 ;; --app) [ "$#" -ge 2 ] || exit 2; app_path="$2"; shift ;; --output) [ "$#" -ge 2 ] || exit 2; output_dir="$2"; shift ;; --dry-run) dry_run=true ;; *) usage >&2; exit 2 ;; esac
  shift
done
if "$dry_run"; then printf 'Would stage and package %s in %s; no publication or credential access\n' "$app_path" "$output_dir"; exit 0; fi
[ -z "${NOTARY_PROFILE:-}" ] || [ -n "${SIGN_IDENTITY:-}" ] || { printf 'Notarization requires SIGN_IDENTITY\n' >&2; exit 2; }
[ -d "$app_path" ] && [ ! -L "$app_path" ] || { printf 'App directory is missing or is a symlink\n' >&2; exit 1; }
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
[ "$identifier" = org.whalegirl.touchbar ] || { printf 'Unexpected app identifier\n' >&2; exit 1; }
if [ -f "$project_dir/scripts/audit-release.py" ]; then /usr/bin/python3 "$project_dir/scripts/audit-release.py" --tree "$project_dir"; fi
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Unexpected app version\n' >&2; exit 1; }
architectures=$(/usr/bin/lipo -archs "$app_path/Contents/MacOS/DSHWhale")
case "$architectures" in *arm64*x86_64*|*x86_64*arm64*) architecture=universal2 ;; arm64) architecture=arm64 ;; x86_64) architecture=x86_64 ;; *) printf 'Unexpected app architecture\n' >&2; exit 1 ;; esac
state=adhoc-unnotarized
if [ -n "${SIGN_IDENTITY:-}" ]; then state=developerid-unnotarized; fi
if [ -n "${NOTARY_PROFILE:-}" ]; then state=notarized; fi
name="WhaleGirlTouchBar-$version-$architecture-$state"
mkdir -p "$output_dir"
for suffix in zip sha256 json; do [ ! -e "$output_dir/$name.$suffix" ] || { printf 'Refusing to overwrite an existing package\n' >&2; exit 1; }; done
stage=$(mktemp -d "$output_dir/.package.XXXXXX")
cleanup() { if [ -n "$stage" ] && [ -d "$stage" ] && [[ "$(basename "$stage")" = .package.* ]]; then /bin/rm -r -- "$stage"; fi; }
trap cleanup EXIT
staged_app="$stage/DSH 鲸鱼娘.app"
/usr/bin/ditto "$app_path" "$staged_app"
if [ -n "${SIGN_IDENTITY:-}" ]; then /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$staged_app"; fi
/usr/bin/codesign --verify --deep --strict "$staged_app"
if [ -f "$project_dir/scripts/audit-release.py" ]; then /usr/bin/python3 "$project_dir/scripts/audit-release.py" --app "$staged_app"; fi
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$staged_app" "$stage/archive.zip"
if [ -n "${NOTARY_PROFILE:-}" ]; then
  /usr/bin/xcrun notarytool submit "$stage/archive.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$stage/notary-result.json"
  /usr/bin/python3 - "$stage/notary-result.json" <<'PY_NOTARY'
import json,sys
if json.load(open(sys.argv[1])).get('status')!='Accepted':raise SystemExit('Apple notarization did not accept this package; nothing published')
PY_NOTARY
  /usr/bin/xcrun stapler staple "$staged_app"
  /bin/rm "$stage/archive.zip"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$staged_app" "$stage/archive.zip"
fi
/bin/mv "$stage/archive.zip" "$output_dir/$name.zip"
(cd "$output_dir" && /usr/bin/shasum -a 256 "$name.zip" > "$name.sha256")
/usr/bin/python3 - "$output_dir/$name.json" "$version" "$architecture" "$state" <<'PY_STATUS'
import json,sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({'version':sys.argv[2],'architecture':sys.argv[3],'distributionStatus':sys.argv[4],'published':False,'requiresPhysicalTouchBar':True,'upstream':'https://github.com/PC2005-cloud/dsh-pet'},indent=2)+'\n')
PY_STATUS
printf 'Packaged: %s.zip\nStatus: %s\n' "$name" "$state"
