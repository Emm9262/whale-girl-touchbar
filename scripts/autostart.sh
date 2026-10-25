#!/bin/bash
set -euo pipefail
operation=${1:-}
case "$operation" in --help|-h|'') printf '%s\n' 'Usage: scripts/autostart.sh enable|disable [--app PATH] [--dry-run]' 'Login startup is opt-in. Only this app’s LaunchAgent is managed.'; exit 0 ;; enable|disable) shift ;; *) exit 2 ;; esac
app_path="$HOME/Applications/DSH 鲸鱼娘.app"
dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in --app) [ "$#" -ge 2 ] || exit 2; app_path="$2"; shift ;; --dry-run) dry_run=true ;; *) printf 'Unknown option\n' >&2; exit 2 ;; esac
  shift
done
label=org.whalegirl.touchbar.autostart
agent_dir="$HOME/Library/LaunchAgents"
agent_path="$agent_dir/$label.plist"
if "$dry_run"; then printf 'Would %s only %s for %s\n' "$operation" "$label" "$app_path"; exit 0; fi
if [ "$operation" = enable ]; then
  [ -d "$app_path" ] && [ ! -L "$app_path" ] || { printf 'Install the app first\n' >&2; exit 1; }
  identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
  [ "$identifier" = org.whalegirl.touchbar ] || { printf 'Unexpected app bundle identifier\n' >&2; exit 1; }
  app_path=$(cd "$app_path" && pwd -P)
  mkdir -p "$agent_dir"
  /usr/bin/python3 - "$agent_path" "$app_path" <<'PY_AGENT'
from pathlib import Path
import os, plistlib, sys
path=Path(sys.argv[1]); label='org.whalegirl.touchbar.autostart'
value={'Label':label,'ProgramArguments':['/usr/bin/open','-g','-a',sys.argv[2]],'RunAtLoad':True,'LimitLoadToSessionType':'Aqua'}
if path.is_symlink():raise SystemExit('Refusing symlink startup configuration')
if path.exists():
    existing=plistlib.loads(path.read_bytes())
    if existing!=value:raise SystemExit('Existing startup configuration differs; disable it first')
else:
    descriptor=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o644)
    with os.fdopen(descriptor,'wb') as stream:plistlib.dump(value,stream,sort_keys=False)
PY_AGENT
  /usr/bin/plutil -lint "$agent_path"
  if ! /bin/launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then /bin/launchctl bootstrap "gui/$(id -u)" "$agent_path"; fi
  printf '%s\n' 'Login startup enabled. Quitting the app will not relaunch it.'
else
  if [ -e "$agent_path" ] || [ -L "$agent_path" ]; then
    /usr/bin/python3 - "$agent_path" <<'PY_AGENT'
from pathlib import Path
import plistlib,sys
p=Path(sys.argv[1])
if p.is_symlink():raise SystemExit('Refusing symlink startup configuration')
v=plistlib.loads(p.read_bytes())
if v.get('Label')!='org.whalegirl.touchbar.autostart':raise SystemExit('Unexpected startup label')
args=v.get('ProgramArguments')
if not isinstance(args,list) or args[:3]!=['/usr/bin/open','-g','-a']:raise SystemExit('Unexpected startup command')
PY_AGENT
    /bin/launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
    /bin/rm "$agent_path"
  fi
  printf '%s\n' 'Login startup disabled; the running app is unchanged.'
fi
