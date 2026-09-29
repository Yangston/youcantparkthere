#!/usr/bin/env python3
"""Install/launch on an available watch simulator and save screenshots. Not a hardware test."""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
BUNDLE = 'com.yangston.youcantparkthere.watchkitapp'

def run(*args: str, timeout: int = 90) -> str:
    print('+ ' + ' '.join(args), flush=True)
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=timeout)
    if result.stdout:
        print(result.stdout, flush=True)
    if result.stderr:
        print(result.stderr, flush=True)
    return result.stdout

def main() -> None:
    BUILD.mkdir(exist_ok=True)
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    candidates = [(runtime, item) for runtime, items in devices.items() if 'watchOS' in runtime
                  for item in items if item.get('isAvailable') and 'Apple Watch' in item['name']]
    if not candidates:
        raise RuntimeError('No available watchOS simulator runtime. Install one to execute the launch check.')
    runtime, device = sorted(candidates, key=lambda pair: (pair[0], pair[1]['name']), reverse=True)[0]
    udid = device['udid']
    print(f"Smoke device: {device['name']} / {runtime}", flush=True)
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', udid)
    try:
        run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=240)
        app = BUILD / 'DerivedData/Build/Products/Debug-watchsimulator/ParkWatch.app'
        if not app.is_dir():
            raise RuntimeError(f'Missing simulator build: {app}')
        run('xcrun', 'simctl', 'install', udid, str(app))
        output = run('xcrun', 'simctl', 'launch', '--terminate-running-process', udid, BUNDLE, '--demo')
        match = re.search(r':\s*(\d+)\s*$', output.strip())
        if not match:
            raise RuntimeError('Simulator did not report a launched process ID.')
        pid = int(match.group(1))
        time.sleep(8)
        os.kill(pid, 0)  # A successful launch request alone does not catch an immediate crash.
        run('xcrun', 'simctl', 'io', udid, 'screenshot', str(BUILD / 'demo-docks.png'))
        for mode in ('bikes', 'ride'):
            run('xcrun', 'simctl', 'openurl', udid, f'youcantparkthere://{mode}')
            time.sleep(3)
            os.kill(pid, 0)
            run('xcrun', 'simctl', 'io', udid, 'screenshot', str(BUILD / f'demo-{mode}.png'))
        print('PASS: installed, launched, survived, and handled bike/ride deep links in demo mode.')
        print('Screenshots are review artifacts, not assertions of layout correctness or hardware behavior.')
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', udid], check=False, timeout=30)

if __name__ == '__main__':
    try:
        main()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(getattr(exc, 'stdout', '') or '', file=sys.stderr)
        print(getattr(exc, 'stderr', '') or '', file=sys.stderr)
        raise
