import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dev
import preview_report


class PreviewTests(unittest.TestCase):
    def scenario(self, name):
        return next(s for s in preview_report.catalog()['scenarios'] if s['id'] == name)

    def test_inventory_states_and_empty_data_are_distinct(self):
        self.assertEqual(preview_report.expected_state(self.scenario('docks'))['counts'], [12, 0, 3, 8])
        self.assertEqual(preview_report.expected_state(self.scenario('unavailable'))['counts'], [None, 0, None, 8])
        for name in ('offline', 'stale'):
            self.assertEqual(preview_report.expected_state(self.scenario(name))['counts'], [None] * 4)
        for name in ('empty', 'error'):
            self.assertEqual(preview_report.expected_state(self.scenario(name))['counts'], [])

    def test_wrong_native_state_fails(self):
        value = preview_report.expected_state(self.scenario('stale'))
        value['counts'] = [12, 0, 3, 8]
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            preview_report.validate_state(value, self.scenario('stale'))

    def test_electric_counts_and_removed_list_screen(self):
        self.assertEqual(preview_report.expected_state(self.scenario('bike-types-unknown'))['counts'], [4, 9, 6, 12])
        self.assertEqual(preview_report.expected_state(self.scenario('stale'))['electricCounts'], [None] * 4)
        self.assertEqual(preview_report.expected_state(self.scenario('bikes'))['electricCounts'], [2, 0, 1, None])
        self.assertEqual(preview_report.expected_state(self.scenario('bike-types-unknown'))['electricCounts'], [None, 0, None, None])
        self.assertEqual(preview_report.expected_state(self.scenario('settings'))['screen'], 'settings')
        self.assertFalse(any(s['page'] == 'nearby' for s in preview_report.catalog()['scenarios']))

    def test_missing_and_invalid_captures_are_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'preview-docks.png').write_bytes(b'\x89PNG\r\n\x1a\n')
            (root / 'preview-docks.json').write_text('{}')
            with patch.object(preview_report, 'git_value', return_value='unknown'):
                result = preview_report.build_report(root)
            self.assertEqual(result['entries'][0]['status'], 'failed')
            self.assertTrue(all(e['status'] != 'captured' for e in result['entries']))
            self.assertTrue((root / 'preview/index.html').exists())

    def test_archive_cannot_escape_destination(self):
        for path in ('../private.pem', '/private.pem', 'C:/private.pem', 'screenshots\\evil.png'):
            with self.subTest(path=path), tempfile.TemporaryDirectory() as directory:
                archive = Path(directory) / 'bad.zip'
                with zipfile.ZipFile(archive, 'w') as z: z.writestr(path, 'bad')
                with self.assertRaises(ValueError): dev.import_zip(archive, Path(directory) / 'output')
                self.assertFalse((Path(directory) / 'output').exists())

    def test_import_uses_local_viewer_not_artifact_scripts(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, output = Path(directory) / 'preview.zip', Path(directory) / 'output'
            manifest = {'schema': 1, 'sha': 'a' * 40, 'entries': [], 'checks': {}, 'device': 'Watch'}
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('manifest.json', json.dumps(manifest))
                z.writestr('app.js', 'UNTRUSTED SCRIPT')
            dev.import_zip(archive, output)
            self.assertNotIn('UNTRUSTED SCRIPT', (output / 'app.js').read_text())

    def test_bad_manifest_does_not_overwrite_existing_preview(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'source', Path(directory) / 'output'
            source.mkdir(); output.mkdir()
            old = output / 'manifest.json'; old.write_text('keep')
            (source / 'manifest.json').write_text(json.dumps({'schema': 1, 'sha': 'a' * 40,
                'entries': [{'id': 'docks', 'file': '../private.pem', 'status': 'captured'}]}))
            with self.assertRaises(ValueError): dev.import_folder(source, output)
            self.assertEqual(old.read_text(), 'keep')

    def test_metadata_cannot_end_the_report_script(self):
        with tempfile.TemporaryDirectory() as directory:
            preview_report.write_viewer(directory, {'branch': '</script><script>alert(1)</script>'})
            self.assertNotIn('</script>', (Path(directory) / 'report.js').read_text())

    def test_saved_baseline_is_embedded_without_replacing_current_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'baseline').mkdir()
            old = {'schema': 1, 'sha': 'b' * 40, 'entries': []}
            (root / 'baseline/manifest.json').write_text(json.dumps(old))
            preview_report.write_viewer(root, {'schema': 1, 'sha': 'a' * 40, 'entries': []})
            payload = (root / 'report.js').read_text()[len('window.PARK_DATA = '):].rstrip(';\n')
            data = json.loads(payload)
            self.assertEqual(data['report']['sha'], 'a' * 40)
            self.assertEqual(data['baseline']['sha'], 'b' * 40)


if __name__ == '__main__': unittest.main()
