#!/usr/bin/env python3
"""Generate a deterministic, opaque 1024px app icon without external dependencies."""
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xffffffff)

def main() -> None:
    size = 1024
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            # Bold parking P: vertical stem, rounded bowl, cutout, small availability dot.
            stem = 300 <= x < 420 and 235 <= y < 790
            outer = 370 <= x <= 570 and 235 <= y < 575 or ((x - 570) / 170) ** 2 + ((y - 405) / 170) ** 2 <= 1
            hole = 420 <= x <= 568 and 340 <= y < 470 or ((x - 568) / 65) ** 2 + ((y - 405) / 65) ** 2 <= 1
            dot = (x - 685) ** 2 + (y - 738) ** 2 <= 57 ** 2
            ink = (stem or outer) and not hole or dot
            raw.extend((24, 26, 29) if ink else (255, 156, 56))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    assets = ROOT / 'WatchApp/Assets.xcassets'
    icon = assets / 'AppIcon.appiconset'
    icon.mkdir(parents=True, exist_ok=True)
    (assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}))
    (icon / 'AppIcon.png').write_bytes(png)
    (icon / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'watchos', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1}
    }, indent=2))
    print('Generated WatchApp/Assets.xcassets/AppIcon.appiconset')

if __name__ == '__main__':
    main()
