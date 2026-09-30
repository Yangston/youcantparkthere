import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_app_store import SCENARIOS, validate_listing, verify_captures, write_site


class AppStorePackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        (self.folder / 'screenshots').mkdir()
        self.manifest = {'sha': 'a' * 40, 'checks': dict.fromkeys(('helpers', 'core', 'compile', 'archive', 'smoke'), 'success'),
                         'entries': [{'id': i, 'status': 'captured', 'file': f'screenshots/{i}.png'} for i in SCENARIOS]}
        for i in SCENARIOS:
            (self.folder / f'screenshots/{i}.png').write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0\0\0\rIHDR' + struct.pack('!II', 422, 514))
        self.save()

    def save(self):
        (self.folder / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_stale_commit_cannot_supply_release_screenshots(self):
        with self.assertRaisesRegex(ValueError, 'commit'):
            verify_captures(self.folder, 'b' * 40)

    def test_incomplete_validation_cannot_supply_release_screenshots(self):
        self.manifest['checks']['smoke'] = 'failure'
        self.save()
        with self.assertRaisesRegex(ValueError, 'validation'):
            verify_captures(self.folder, 'a' * 40)

    def test_missing_capture_and_wrong_watch_size_rejected(self):
        self.manifest['entries'][0]['status'] = 'missing'
        self.save()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            verify_captures(self.folder, 'a' * 40)
        self.manifest['entries'][0]['status'] = 'captured'
        self.save()
        (self.folder / 'screenshots/docks.png').write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0\0\0\rIHDR' + struct.pack('!II', 324, 394))
        with self.assertRaisesRegex(ValueError, '422'):
            verify_captures(self.folder, 'a' * 40)

    def test_listing_rejects_overlong_subtitle(self):
        listing = {'name': 'Park', 'subtitle': 'a' * 31, 'keywords': 'bike', 'promotional_text': 'Find a dock.'}
        with self.assertRaisesRegex(ValueError, 'subtitle'):
            validate_listing(listing, 'Description')

    def test_site_escapes_contact_and_policy_content(self):
        write_site(self.folder, {'support_email': 'test@example.com'}, {'updated': '2026-09-30', 'sections': [{'title': '<script>', 'body': '<img onerror=evil>'}]})
        page = (self.folder / 'privacy.html').read_text()
        self.assertIn('&lt;script&gt;', page)
        self.assertNotIn('<img onerror=', page)
        self.assertIn('mailto:test@example.com', page)
