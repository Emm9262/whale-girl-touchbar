#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
app_path="$project_dir/build/DSH 鲸鱼娘.app"
output_dir="$project_dir/build/test-results"
dry_run=false
app_set=false
usage() { printf '%s\n' 'Usage: scripts/test.sh [app-path] [--output DIR] [--dry-run]' 'Runs native behavior checks and an isolated loopback HTTP fixture. No real DSH calls.'; }
while [ "$#" -gt 0 ]; do
 case "$1" in --help|-h) usage; exit 0 ;; --output) [ "$#" -ge 2 ] || exit 2; output_dir="$2"; shift ;; --dry-run) dry_run=true ;; --*) usage >&2; exit 2 ;; *) if "$app_set"; then usage >&2; exit 2; fi; app_path="$1"; app_set=true ;; esac
 shift
done
if "$dry_run"; then printf 'Would test %s using isolated fixture servers; reports in %s\n' "$app_path" "$output_dir"; exit 0; fi
[ -x "$app_path/Contents/MacOS/DSHWhale" ] || { printf 'Build the app first\n' >&2; exit 1; }
mkdir -p "$output_dir"
"$app_path/Contents/MacOS/DSHWhale" --behavior-tests > "$output_dir/native-behavior.json"
/usr/bin/clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 \
  "-ffile-prefix-map=$project_dir=." "-fmacro-prefix-map=$project_dir=." -framework Foundation \
  "$project_dir/Tests/WhaleBackendHTTPTests.m" "$project_dir/Sources/WhaleBackend.m" -o "$output_dir/backend-http-tests"
/usr/bin/python3 "$project_dir/Tests/backend_http_fixture.py" "$output_dir/backend-http-tests" "$output_dir/http" > "$output_dir/http-fixture-summary.txt"
/usr/bin/python3 - "$output_dir/native-behavior.json" "$output_dir/http/backend-http-fixture-report.json" <<'PY_TEST'
import json,sys
native=json.load(open(sys.argv[1]));fixture=json.load(open(sys.argv[2]));failed=[key for key,value in native.items() if not value.get('passed')]
if failed or not fixture.get('passed'):raise SystemExit('Native or isolated HTTP checks failed; see local reports')
print(json.dumps({'passed':True,'nativeChecks':sum(len(value.get('checks',[])) for value in native.values()),'fixturePassed':fixture.get('passed'),'realDSHCalled':False}))
PY_TEST
if [ -f "$project_dir/Tests/test_release_audit.py" ]; then
  /usr/bin/python3 -m unittest discover -s "$project_dir/Tests" -p test_release_audit.py
fi
if [ -f "$project_dir/Tests/bridge-setup.test.mjs" ]; then
  node_bin=${NODE_BIN:-node}
  command -v "$node_bin" >/dev/null || { printf 'Node.js is required for bridge setup tests; set NODE_BIN if needed\n' >&2; exit 1; }
  "$node_bin" --test "$project_dir/Tests/bridge-setup.test.mjs"
fi
