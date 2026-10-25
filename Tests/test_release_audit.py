import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

spec = importlib.util.spec_from_file_location('release_audit', Path(__file__).resolve().parents[1] / 'scripts/audit-release.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class ReleaseAuditTests(unittest.TestCase):
    def test_sensitive_names_are_flagged_without_reading(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / '.env'
            path.write_text('do not read')
            with mock.patch.object(Path, 'read_bytes', side_effect=AssertionError('forbidden read')):
                files, findings = audit.tree_scan(root)
            self.assertEqual(files, 0)
            self.assertEqual(findings[0]['rule'], 'sensitive-filename-not-read')

    def test_matching_values_never_appear_in_output(self):
        sample = ('gh' + 'p_' + 'A' * 36).encode()
        found = audit.content_findings('Sources/example.m', b'line one\n' + sample)
        self.assertTrue(found)
        output = json.dumps(found).encode()
        self.assertNotIn(sample, output)
        self.assertEqual(found[0]['line'], 2)

    def test_personal_path_is_detected_without_being_echoed(self):
        sample = ('/' + 'Users/' + 'sampleperson/project').encode()
        found = audit.content_findings('README.md', sample)
        self.assertTrue(found)
        self.assertNotIn(sample, json.dumps(found).encode())

    def test_known_local_install_record_is_not_read(self):
        self.assertTrue(audit.name_findings('Support/Bridge-installation.json'))

    def test_source_symlinks_cannot_import_external_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').symlink_to(root / 'not-present')
            _, found = audit.tree_scan(root)
            self.assertEqual(found[0]['rule'], 'symlink-not-published')

    def test_archive_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'candidate.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('../outside.txt', 'not read')
            _, found = audit.archive_scan(path)
            self.assertEqual(found[0]['rule'], 'unsafe-archive-path')

    def test_ordinary_public_source_passes(self):
        self.assertEqual(audit.content_findings('Sources/example.m', b'const char *name = "Whale Girl";'), [])


if __name__ == '__main__':
    unittest.main()
