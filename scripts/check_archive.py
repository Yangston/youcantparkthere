#!/usr/bin/env python3
"""Fail CI when the distributable archive is missing its watch app or complication."""
import json
import plistlib
import sys
from pathlib import Path

archive = Path(sys.argv[1])
apps = list((archive / 'Products/Applications').glob('*.app'))
assert len(apps) == 1, f'Expected one iOS watch-only container, found {apps}'
with (apps[0] / 'Info.plist').open('rb') as f:
    container = plistlib.load(f)
assert container.get('ITSWatchOnlyContainer') is True, 'Not a watch-only container'
# App Store Connect checks the distribution container as well as the watch app.
# ITMS-90683 rejects a container without the embedded app's motion purpose string.
motion_purpose = container.get('NSMotionUsageDescription')
assert isinstance(motion_purpose, str) and motion_purpose.strip(), \
    'Container Info.plist is missing a non-empty NSMotionUsageDescription (ITMS-90683)'
watches = list((apps[0] / 'Watch').glob('*.app'))
assert len(watches) == 1, 'Watch app was not embedded'
with (watches[0] / 'Info.plist').open('rb') as f:
    watch = plistlib.load(f)
assert watch.get('WKWatchOnly') is True and watch.get('WKApplication') is True
assert 'location' in watch.get('UIBackgroundModes', []), 'Missing navigation background mode'
assert watch.get('NSMotionUsageDescription') and watch.get('NSLocationWhenInUseUsageDescription')
assert (watches[0] / 'PrivacyInfo.xcprivacy').is_file(), 'Missing privacy manifest'
policy_path = watches[0] / 'privacy-policy.json'
assert policy_path.is_file(), 'Missing offline privacy policy'
policy = json.loads(policy_path.read_text(encoding='utf-8'))
assert policy.get('updated') and policy.get('supportURL') and policy.get('sections'), 'Invalid offline privacy policy'
assert all(s.get('title') and s.get('body') for s in policy['sections']), 'Invalid policy sections'
widgets = list((watches[0] / 'PlugIns').glob('*.appex'))
assert len(widgets) == 1, 'Widget extension was not embedded'
print('Archive structure OK: watch-only container, watch app, widgets, permissions, privacy manifest.')
