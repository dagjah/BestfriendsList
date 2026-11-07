"""Validate upload requests against the documented API without sending them."""
from contextlib import contextmanager
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('curseforge', ROOT / 'scripts/curseforge.py')
curseforge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(curseforge)


class UploadTests(unittest.TestCase):
    @contextmanager
    def configured(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            try:
                os.chdir(directory)
                Path('dist').mkdir()
                Path('dist/BestfriendsList-install.zip').write_bytes(b'test-package')
                Path('CHANGELOG.md').write_text('Release notes')
                with patch.dict(os.environ, {
                    'CF_API_TOKEN': 'test-token', 'CF_PROJECT_ID': '123',
                    'CF_GAME_VERSION_IDS': '456, 789', 'RELEASE_TAG': 'v2.4.0',
                }, clear=True):
                    yield
            finally:
                os.chdir(previous)

    def test_configuration_lookup_is_get_only(self):
        with self.configured():
            data = b'[{"id":456,"name":"Supported A"},{"id":789,"name":"Supported B"}]'
            with patch('urllib.request.urlopen', return_value=io.BytesIO(data)) as send:
                curseforge.check_configuration()
            request = send.call_args.args[0]
            self.assertEqual(request.full_url, 'https://wow.curseforge.com/api/game/versions')
            self.assertEqual(request.get_method(), 'GET')
            self.assertIsNone(request.data)
            self.assertEqual(send.call_count, 1)

    def test_unknown_game_version_prevents_upload(self):
        with self.configured():
            with patch('urllib.request.urlopen', return_value=io.BytesIO(b'[{"id":456,"name":"Supported A"}]')) as send:
                with self.assertRaises(SystemExit) as result:
                    curseforge.check_configuration()
            self.assertIn('789', str(result.exception))
            self.assertEqual(send.call_count, 1)
            self.assertEqual(send.call_args.args[0].get_method(), 'GET')

    def test_upload_fields_and_authentication(self):
        with self.configured():
            with patch('urllib.request.urlopen', return_value=io.BytesIO(b'{"id": 321}')) as send:
                curseforge.main()
            request = send.call_args.args[0]
            self.assertEqual(request.full_url, 'https://wow.curseforge.com/api/projects/123/upload-file')
            self.assertEqual(request.get_method(), 'POST')
            self.assertEqual(request.get_header('X-api-token'), 'test-token')
            self.assertIn(b'name="metadata"', request.data)
            self.assertIn(b'"gameVersions": [456, 789]', request.data)
            self.assertIn(b'"releaseType": "release"', request.data)
            self.assertIn(b'test-package', request.data)
            self.assertNotIn(b'test-token', request.data)

    def test_missing_configuration_never_sends(self):
        with self.configured():
            for field in ('CF_API_TOKEN', 'CF_PROJECT_ID', 'CF_GAME_VERSION_IDS'):
                with patch.dict(os.environ, {field: ''}):
                    with patch('urllib.request.urlopen') as send:
                        with self.assertRaises(SystemExit):
                            curseforge.main()
                        send.assert_not_called()

    def test_api_rejection_has_no_token_or_response_body_in_error(self):
        with self.configured():
            error = urllib.error.HTTPError('url', 403, 'test-token', {}, None)
            with patch('urllib.request.urlopen', side_effect=error):
                with self.assertRaises(SystemExit) as result:
                    curseforge.main()
            self.assertIn('HTTP 403', str(result.exception))
            self.assertNotIn('test-token', str(result.exception))


if __name__ == '__main__':
    unittest.main()
