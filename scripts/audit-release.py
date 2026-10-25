#!/usr/bin/env python3
"""Audit publication candidates without printing file contents or secret values."""
from __future__ import annotations
import argparse
import io
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

IGNORED = {'.git', 'build', 'dist', 'node_modules', '__pycache__', '.pytest_cache'}
ROOT_FILES = {'README.md', 'README.en.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
              'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md', 'VERSION',
              '.gitignore', '.gitattributes', '.gitleaks.toml', 'build.sh'}
ROOT_DIRS = {'Sources', 'Resources', 'Support', 'Tests', 'scripts', 'docs', '.github'}
BLOCKED_NAME = re.compile(r'(?i)(^|[-_.])(password|passwd|credentials?|secrets?|tokens?|id_rsa|id_ed25519)([-_.]|$)')
BLOCKED_SUFFIX = {'.p12', '.pfx', '.pem', '.key', '.keystore', '.mobileprovision', '.provisionprofile', '.log', '.jsonl', '.pyc', '.zip', '.tgz', '.tar', '.gz', '.dmg'}
BLOCKED_FILES = {'backup-location.txt', 'Bridge-installation.json', 'pc2005-runtime.json', '.DS_Store'}
PATTERNS = [
    ('personal-home-path', re.compile(rb'/(?:Users|home)/[A-Za-z0-9._-]+/')),
    ('private-signing-key', re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    ('service-credential', re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|AIza[A-Za-z0-9_-]{30,})\b')),
    ('jwt-value', re.compile(rb'\beyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\b')),
    ('literal-credential', re.compile(rb'''(?i)\b(?:api[_-]?key|access[_-]?token|client[_-]?secret|password|passwd)\b\s*[:=]\s*["']([A-Za-z0-9+/=_-]{12,})["']''')),
    ('private-app-namespace', re.compile(rb'(?:local\.codex\.dsh|local\.dsh\.whale|DSHWhale(?:TouchBar))')),
]


def issue(path: str, rule: str, line: int | None = None):
    result = {'path': path, 'rule': rule}
    if line is not None:
        result['line'] = line
    return result


def name_findings(name: str, source: bool = True):
    parts = PurePosixPath(name).parts
    if not parts or PurePosixPath(name).is_absolute() or '..' in parts:
        return [issue(name, 'unsafe-path')]
    for part in parts:
        if part == '.env' or part.startswith('.env.') or BLOCKED_NAME.search(part):
            return [issue(name, 'sensitive-filename-not-read')]
        if part in BLOCKED_FILES or Path(part).suffix.lower() in BLOCKED_SUFFIX:
            return [issue(name, 'local-or-sensitive-file-not-read')]
    if source:
        if len(parts) == 1 and parts[0] not in ROOT_FILES:
            return [issue(name, 'unapproved-root-file')]
        if len(parts) > 1 and parts[0] not in ROOT_DIRS:
            return [issue(name, 'unapproved-root-directory')]
    return []


def content_findings(name: str, data: bytes):
    found = []
    for label, pattern in PATTERNS:
        for match in pattern.finditer(data):
            found.append(issue(name, label, data.count(b'\n', 0, match.start()) + 1))
    return found


def tree_scan(root: Path, app: bool = False):
    findings, files = [], 0
    def visit(folder: Path):
        nonlocal files
        for path in sorted(folder.iterdir()):
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                findings.append(issue(relative, 'symlink-not-published'))
                continue
            if path.is_dir():
                if path.name not in IGNORED:
                    visit(path)
                continue
            if not path.is_file():
                findings.append(issue(relative, 'nonregular-file'))
                continue
            bad = name_findings(relative, source=not app)
            if bad:
                findings.extend(bad)
                continue
            files += 1
            findings.extend(content_findings(relative, path.read_bytes()))
    visit(root)
    return files, findings


def archive_scan(path: Path, app: bool = False):
    findings, files = [], 0
    with zipfile.ZipFile(path) as archive:
        entries = [item for item in archive.infolist() if not item.is_dir()]
        roots = {PurePosixPath(item.filename).parts[0] for item in entries if PurePosixPath(item.filename).parts}
        strip = not app and len(roots) == 1 and any('/README.md' in item.filename for item in entries)
        for item in entries:
            original = PurePosixPath(item.filename)
            if original.is_absolute() or '..' in original.parts:
                findings.append(issue(item.filename, 'unsafe-archive-path'))
                continue
            name = PurePosixPath(*original.parts[1:]).as_posix() if strip else item.filename
            if '.git' in original.parts or item.file_size > 100 * 1024 * 1024:
                findings.append(issue(name, 'history-or-oversize-archive-member'))
                continue
            if (item.external_attr >> 16) & 0o170000 == 0o120000:
                findings.append(issue(name, 'symlink-not-published'))
                continue
            bad = name_findings(name, source=not app)
            if bad:
                findings.extend(bad)
                continue
            files += 1
            findings.extend(content_findings(name, archive.read(item)))
    return files, findings


def git_scan(root: Path, history: bool):
    def git(*args, check=True):
        return subprocess.run(['git', '-C', str(root), *args], check=check, capture_output=True).stdout
    findings, files = [], 0
    if history:
        commits = git('rev-list', '--all').decode().splitlines()
        candidates = []
        for commit in commits:
            for name in git('ls-tree', '-r', '--name-only', '-z', commit).decode().split('\0'):
                if name:
                    candidates.append((f'{commit}:{name}', name))
    else:
        commits = []
        candidates = [(f':{name}', name) for name in git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').decode().split('\0') if name]
    for spec, name in candidates:
        bad = name_findings(name)
        if bad:
            findings.extend(bad)
            continue
        files += 1
        findings.extend(content_findings(name, git('show', spec)))
    return files, findings, len(commits)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tree', type=Path)
    parser.add_argument('--app', type=Path)
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--app-archive', type=Path)
    parser.add_argument('--staged', action='store_true')
    parser.add_argument('--history', action='store_true')
    args = parser.parse_args(argv)
    root = (args.tree or Path.cwd()).resolve()
    reports = []
    if args.app:
        count, findings = tree_scan(args.app.resolve(), app=True)
        reports.append({'scope': 'application', 'files': count, 'findings': findings})
    elif args.app_archive:
        count, findings = archive_scan(args.app_archive.resolve(), app=True)
        reports.append({'scope': 'application-archive', 'files': count, 'findings': findings})
    elif args.archive:
        count, findings = archive_scan(args.archive.resolve())
        reports.append({'scope': 'source-archive', 'files': count, 'findings': findings})
    else:
        count, findings = tree_scan(root)
        reports.append({'scope': 'source-tree', 'files': count, 'findings': findings})
    for flag, history in [(args.staged, False), (args.history, True)]:
        if flag:
            count, findings, commits = git_scan(root, history)
            reports.append({'scope': 'git-history' if history else 'git-staged', 'files': count, 'commits': commits, 'findings': findings})
    passed = not any(report['findings'] for report in reports)
    print(json.dumps({'passed': passed, 'reports': reports, 'redacted': True,
                      'limits': 'Pattern audit, not a proof that arbitrary sensitive information is absent; manually review the publication allowlist and use a dedicated secret scanner as well.'}, ensure_ascii=False, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
