#!/usr/bin/env python3
"""Run local, redacted Gitleaks checks. Candidate files are never uploaded."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import urllib.request

VERSION = '8.30.1'
PACKAGES = {
    'arm64': ('darwin_arm64', 'b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5'),
    'x86_64': ('darwin_x64', 'dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709'),
}
ROOT = Path(__file__).resolve().parents[1]


def scanner_path(explicit):
    if explicit:
        path = Path(explicit).resolve()
        if not path.is_file() or not os.access(path, os.X_OK):
            raise SystemExit('Selected scanner is not executable')
        return path
    if platform.system() != 'Darwin' or platform.machine() not in PACKAGES:
        raise SystemExit('Use --scanner with a trusted local Gitleaks executable on this platform')
    package, expected = PACKAGES[platform.machine()]
    cache = ROOT / 'build' / 'audit-tools'
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / f'gitleaks_{VERSION}_{package}.tar.gz'
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        url = f'https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/{archive.name}'
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise SystemExit('Official scanner checksum mismatch; nothing will be executed')
        archive.write_bytes(data)
    binary = cache / f'gitleaks-{VERSION}'
    with tarfile.open(archive, 'r:gz') as tar:
        member = tar.getmember('gitleaks')
        if not member.isfile():
            raise SystemExit('Unexpected scanner archive')
        binary.write_bytes(tar.extractfile(member).read())
        binary.chmod(0o700)
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scanner', type=Path)
    parser.add_argument('--staged', action='store_true')
    parser.add_argument('--history', action='store_true')
    args = parser.parse_args()
    binary = scanner_path(args.scanner)
    reports = ROOT / 'build' / 'audit-reports'
    reports.mkdir(parents=True, exist_ok=True)
    jobs = [('working-tree', ['dir', str(ROOT)])]
    if args.staged:
        jobs.append(('staged', ['git', '--pre-commit', '--staged', str(ROOT)]))
    if args.history:
        commits = subprocess.run(['git', '-C', str(ROOT), 'rev-list', '--all', '--count'], capture_output=True, check=True, text=True).stdout.strip()
        if commits != '0':
            jobs.append(('history', ['git', str(ROOT), '--log-opts=--all']))
    summary = []
    for label, command in jobs:
        report = reports / f'gitleaks-{label}.json'
        result = subprocess.run([str(binary), *command, '--redact=100', '--no-banner', '--no-color', '--log-level', 'error', '--report-format', 'json', '--report-path', str(report)], capture_output=True, timeout=120)
        findings = json.loads(report.read_text()) if report.exists() else []
        public = [{'rule': item.get('RuleID'), 'path': str(item.get('File', '')).replace(str(ROOT) + '/', ''), 'line': item.get('StartLine')} for item in findings]
        summary.append({'scope': label, 'exitCode': result.returncode, 'findings': public})
    passed = all(item['exitCode'] == 0 and not item['findings'] for item in summary)
    print(json.dumps({'passed': passed, 'redacted': True, 'reports': summary, 'uploadsCandidateFiles': False}, ensure_ascii=False, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
