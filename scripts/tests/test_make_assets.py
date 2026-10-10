import contextlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import make_assets


class AppIconTests(unittest.TestCase):
    def test_container_and_watch_have_identical_opaque_artwork(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with contextlib.redirect_stdout(io.StringIO()):
                make_assets.main(root)
            images = []
            for folder, platform in [('PhoneApp', 'ios'), ('WatchApp', 'watchos')]:
                icon = root / folder / 'Assets.xcassets/AppIcon.appiconset'
                contents = json.loads((icon / 'Contents.json').read_text())
                entry, = contents['images']
                self.assertEqual(entry['platform'], platform)
                self.assertEqual(entry['size'], '1024x1024')
                png = (icon / entry['filename']).read_bytes()
                self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(struct.unpack('!2I5B', png[16:29]),
                                 (1024, 1024, 8, 2, 0, 0, 0))
                images.append(png)
            self.assertEqual(images[0], images[1])
