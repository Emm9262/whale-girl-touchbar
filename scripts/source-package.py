#!/usr/bin/env python3
"""Create an allowlisted source ZIP, without Git history, caches or local data."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_audit', ROOT / 'scripts/audit-release.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def candidates():
    for path in sorted(ROOT.rglob('*')):
        parts = path.relative_to(ROOT).parts
        if any(part in audit.IGNORED for part in parts):
            continue
        if path.is_file() and not path.is_symlink():
            yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    count, findings = audit.tree_scan(ROOT)
    if findings:
        print(json.dumps({'passed': False, 'findings': findings}, ensure_ascii=False))
        return 1
    version = (ROOT / 'VERSION').read_text().strip()
    if not __import__('re').fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('Invalid VERSION')
    name = f'WhaleGirlTouchBar-{version}-source.zip'
    files = list(candidates())
    if args.dry_run:
        print(json.dumps({'dryRun': True, 'files': len(files), 'archive': name, 'includesHistory': False}))
        return 0
    args.output.mkdir(parents=True, exist_ok=True)
    destination = args.output / name
    # Mode x prevents silently replacing an already-reviewed release candidate.
    with zipfile.ZipFile(destination, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            entry = zipfile.ZipInfo(f'whale-girl-touchbar-{version}/{relative}', (2020, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = (0o100755 if path.stat().st_mode & 0o111 else 0o100644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, path.read_bytes())
    checked, findings = audit.archive_scan(destination)
    if findings:
        print(json.dumps({'passed': False, 'archive': name, 'findings': findings}, ensure_ascii=False))
        return 1
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    with destination.with_suffix('.sha256').open('x') as checksum:
        checksum.write(f'{digest}  {name}\n')
    print(json.dumps({'passed': True, 'files': checked, 'archive': name, 'sha256': digest, 'includesHistory': False}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
