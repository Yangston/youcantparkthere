from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


CHECK_ARCHIVE = Path(__file__).resolve().parents[1] / 'check_archive.py'


class ArchivePermissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / 'Park.xcarchive'
        self.container = self.archive / 'Products/Applications/ParkContainer.app'
        self.watch = self.container / 'Watch/ParkWatch.app'
        (self.watch / 'PlugIns/ParkWidgets.appex').mkdir(parents=True)
        self.watch_info = {
            'WKWatchOnly': True,
            'WKApplication': True,
            'UIBackgroundModes': ['location'],
            'NSMotionUsageDescription': 'Detect cycling when enabled.',
            'NSLocationWhenInUseUsageDescription': 'Find nearby stations.',
        }
        self.write_plist(self.watch, self.watch_info)
        (self.watch / 'PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({}))

    def write_plist(self, bundle, info):
        (bundle / 'Info.plist').write_bytes(plistlib.dumps(info))

    def check(self, container_info):
        self.write_plist(self.container, container_info)
        return subprocess.run(
            [sys.executable, str(CHECK_ARCHIVE), str(self.archive)],
            capture_output=True, text=True, check=False,
        )

    def test_valid_container_and_watch_permissions_pass(self):
        result = self.check({
            'ITSWatchOnlyContainer': True,
            'NSMotionUsageDescription': 'Detect cycling on your Apple Watch when enabled.',
        })
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_watch_permission_does_not_replace_container_permission(self):
        for value in (None, '', '   ', True):
            with self.subTest(value=value):
                info = {'ITSWatchOnlyContainer': True}
                if value is not None:
                    info['NSMotionUsageDescription'] = value
                result = self.check(info)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Container Info.plist', result.stderr)
                self.assertIn('NSMotionUsageDescription', result.stderr)

    def test_container_permission_does_not_replace_watch_permission(self):
        del self.watch_info['NSMotionUsageDescription']
        self.write_plist(self.watch, self.watch_info)
        result = self.check({
            'ITSWatchOnlyContainer': True,
            'NSMotionUsageDescription': 'Detect cycling on your Apple Watch when enabled.',
        })
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
