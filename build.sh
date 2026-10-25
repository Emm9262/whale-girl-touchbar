#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
usage() { cat <<'HELP'
Usage: ./build.sh [output-directory] [--dry-run]
Builds a new app without replacing an existing one. Default output: build/.
ARCHS="arm64 x86_64" (default universal2), ARCHS=arm64, or ARCHS=x86_64.
BUILD_NUMBER defaults to 123. Local builds use an ad-hoc signature.
HELP
}
output_dir="$project_dir/build"
dry_run=false
output_set=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) dry_run=true ;;
    --*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) if "$output_set"; then usage >&2; exit 2; fi; output_dir="$1"; output_set=true ;;
  esac
  shift
done
version=$(tr -d '\r\n' < "$project_dir/VERSION")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'VERSION must be numeric X.Y.Z\n' >&2; exit 2; }
build_number=${BUILD_NUMBER:-123}
[[ "$build_number" =~ ^[0-9]+$ ]] || { printf 'BUILD_NUMBER must be numeric\n' >&2; exit 2; }
read -r -a architectures <<< "${ARCHS:-arm64 x86_64}"
[ "${#architectures[@]}" -gt 0 ] || { printf 'ARCHS must not be empty\n' >&2; exit 2; }
arch_flags=()
for architecture in "${architectures[@]}"; do
  case "$architecture" in arm64|x86_64) arch_flags+=(-arch "$architecture") ;; *) printf 'Unsupported architecture\n' >&2; exit 2 ;; esac
done
app_dir="$output_dir/DSH 鲸鱼娘.app"
if "$dry_run"; then printf 'Would build %s (%s), version %s, build %s\n' "$app_dir" "${architectures[*]}" "$version" "$build_number"; exit 0; fi
[ "$(uname -s)" = Darwin ] || { printf 'macOS with Xcode Command Line Tools is required\n' >&2; exit 1; }
[ ! -e "$app_dir" ] || { printf 'Refusing to replace an existing app; choose a fresh output directory\n' >&2; exit 1; }
mkdir -p "$output_dir"
final_app="$app_dir"
stage=$(mktemp -d "$output_dir/.build.XXXXXX")
cleanup() { if [ -n "$stage" ] && [ -d "$stage" ] && [[ "$(basename "$stage")" = .build.* ]]; then /bin/rm -r -- "$stage"; fi; }
trap cleanup EXIT
app_dir="$stage/DSH 鲸鱼娘.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
/usr/bin/clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter \
  "${arch_flags[@]}" -mmacosx-version-min=13.0 \
  "-ffile-prefix-map=$project_dir=." "-fmacro-prefix-map=$project_dir=." \
  -framework Cocoa -framework QuartzCore \
  "$project_dir/Sources/main.m" "$project_dir/Sources/WhaleScene.m" \
  "$project_dir/Sources/WhaleBackend.m" "$project_dir/Sources/CatCompanion.m" \
  "$project_dir/Sources/PetBarContainer.m" "$project_dir/Sources/CompanionPanelView.m" \
  "$project_dir/Sources/PCPetAnimation.m" -o "$app_dir/Contents/MacOS/DSHWhale"
/usr/bin/plutil -create xml1 "$app_dir/Contents/Info.plist"
plist="$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string DSHWhale' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string org.whalegirl.touchbar' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string DSH 鲸鱼娘' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string DSH 鲸鱼娘' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string WhaleGirl.icns' "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 13.0' "$plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$plist"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$plist"
/usr/libexec/PlistBuddy -c 'Add :NSHumanReadableCopyright string Whale Girl Touch Bar contributors. PC2005/dsh-pet animation assets: non-commercial with attribution, https://github.com/PC2005-cloud/dsh-pet. Original whale-girl code: MIT, Sam Gao; character: ZipZipPipe. See bundled notices.' "$plist"
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' "$plist"
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true' "$plist"
/usr/bin/ditto "$project_dir/Resources" "$app_dir/Contents/Resources"
for notice in LICENSE THIRD_PARTY_NOTICES.md; do
  if [ -f "$project_dir/$notice" ]; then /bin/cp "$project_dir/$notice" "$app_dir/Contents/Resources/$notice"; fi
done
/usr/bin/codesign --force --sign - "$app_dir"
/usr/bin/codesign --verify --deep --strict "$app_dir"
/bin/mv "$app_dir" "$final_app"
printf '%s\n' "$final_app"
