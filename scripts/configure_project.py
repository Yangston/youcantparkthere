#!/usr/bin/env python3
"""Set the concrete bundle prefix before the signing tool resolves build settings."""
import os
import re
from pathlib import Path

bundle = os.environ.get('BUNDLE_ID', 'com.yangston.youcantparkthere')
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
    raise SystemExit('Invalid BUNDLE_ID')
path = Path(__file__).resolve().parents[1] / 'project.yml'
text, count = re.subn(r'(?m)^(\s+PARK_BUNDLE_ID: ).+$', lambda m: m[1] + bundle, path.read_text())
assert count == 1, 'PARK_BUNDLE_ID setting missing or duplicated'
path.write_text(text)
