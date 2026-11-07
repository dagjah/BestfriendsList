"""Release artifact boundaries and version guards; no network access."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package', ROOT / 'scripts/package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackagingTests(unittest.TestCase):
    def test_reproducible_install_with_data_only_migration(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = [Path(directory) / name for name in ('first.zip', 'second.zip')]
            package.build(first)
            package.build(second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                expected = {'BestfriendsList/' + name for name in package.RUNTIME + ['BestfriendsList.toc', 'README.md', 'LICENSE']}
                expected.update(f'{old}/{old}.toc' for old in ('KillList', 'KillOnSite', 'KillOnSight'))
                self.assertEqual(set(archive.namelist()), expected)
                for name in package.RUNTIME:
                    self.assertEqual(archive.read('BestfriendsList/' + name), (ROOT / name).read_bytes())
                self.assertEqual(archive.read('BestfriendsList/LICENSE'), (ROOT / 'LICENSE').read_bytes())
                for old in ('KillList', 'KillOnSite', 'KillOnSight'):
                    text = archive.read(f'{old}/{old}.toc').decode()
                    self.assertIn(f'## SavedVariables: {old}DB\n', text)
                    self.assertTrue(all(not line or line.startswith('#') for line in text.splitlines()))

    def test_rejects_mismatched_release_tag_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'bad.zip'
            with self.assertRaises(ValueError):
                package.build(output, 'v0.0.0-invalid')
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
