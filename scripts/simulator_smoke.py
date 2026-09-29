#!/usr/bin/env python3
"""Launch on a disposable paired watch simulator. This is not a hardware test."""
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


def runtime_version(runtime: str) -> tuple[int, ...]:
    match = re.search(r'(?:watchOS|iOS)-(\d+(?:-\d+)*)$', runtime)
    return tuple(map(int, match.group(1).split('-'))) if match else (0,)


def create_device(name: str, template: dict, runtime: str) -> str:
    device_type = template.get('deviceTypeIdentifier') or template['name']
    output = run('xcrun', 'simctl', 'create', name, device_type, runtime).strip()
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', output):
        raise RuntimeError(f'Expected a simulator UDID, got {output!r}')
    return output


def activate_pair(pair_id: str) -> None:
    try:
        run('xcrun', 'simctl', 'pair_activate', pair_id)
    except subprocess.CalledProcessError as exc:
        # Some runtimes activate a freshly created pair automatically. Accept only
        # this documented-by-the-command result; every other error remains fatal.
        message = (exc.stdout or '') + (exc.stderr or '')
        if exc.returncode != 37 or 'This pair is already active.' not in message:
            raise
        print('The new simulator pair is already active; continuing.', flush=True)


def boot_if_needed(udid: str) -> None:
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', '--json'))['devices']
    device = next(item for items in devices.values() for item in items if item['udid'] == udid)
    if device['state'] == 'Shutdown':
        run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=240)


def main() -> None:
    BUILD.mkdir(exist_ok=True)
    app = BUILD / 'DerivedData/Build/Products/Debug-watchsimulator/ParkWatch.app'
    if not app.is_dir():
        raise RuntimeError(f'Missing simulator build: {app}')
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    watches = [(runtime, item) for runtime, items in devices.items() if 'watchOS' in runtime
               for item in items if item.get('isAvailable') and 'Apple Watch' in item['name']]
    phones = [(runtime, item) for runtime, items in devices.items() if '.iOS-' in runtime
              for item in items if item.get('isAvailable') and item['name'].startswith('iPhone')]
    if not watches or not phones:
        raise RuntimeError('The launch check requires both watchOS and iOS simulator runtimes.')
    watch_runtime, watch = max(watches, key=lambda item: (runtime_version(item[0]), item[1]['name']))
    phone_runtime, phone = max(phones, key=lambda item: (
        runtime_version(item[0]) == runtime_version(watch_runtime),
        runtime_version(item[0]), tuple(map(int, re.findall(r'\d+', item[1]['name']))) or (0,)))
    print(f"Smoke pair: {watch['name']} / {watch_runtime} + {phone['name']} / {phone_runtime}", flush=True)
    created: list[str] = []
    pair_id = None
    try:
        phone_id = create_device('Park Smoke iPhone', phone, phone_runtime)
        created.append(phone_id)
        watch_id = create_device('Park Smoke Watch', watch, watch_runtime)
        created.append(watch_id)
        pair_id = run('xcrun', 'simctl', 'pair', watch_id, phone_id).strip()
        activate_pair(pair_id)
        boot_if_needed(phone_id)
        boot_if_needed(watch_id)
        run('xcrun', 'simctl', 'list', 'pairs')
        run('xcrun', 'simctl', 'install', watch_id, str(app))
        output = run('xcrun', 'simctl', 'launch', '--terminate-running-process', watch_id, BUNDLE, '--demo')
        match = re.search(r':\s*(\d+)\s*$', output.strip())
        if not match:
            raise RuntimeError('Simulator did not report a launched process ID.')
        pid = int(match.group(1))
        time.sleep(8)
        os.kill(pid, 0)
        run('xcrun', 'simctl', 'io', watch_id, 'screenshot', str(BUILD / 'demo-docks.png'))
        for mode in ('bikes', 'ride'):
            run('xcrun', 'simctl', 'openurl', watch_id, f'youcantparkthere://{mode}')
            time.sleep(3)
            os.kill(pid, 0)
            run('xcrun', 'simctl', 'io', watch_id, 'screenshot', str(BUILD / f'demo-{mode}.png'))
        print('PASS: installed, launched, survived, and handled bike/ride deep links in demo mode.')
        print('Screenshots are review artifacts, not assertions of layout correctness or hardware behavior.')
    finally:
        for udid in reversed(created):
            subprocess.run(['xcrun', 'simctl', 'shutdown', udid], check=False, timeout=30)
        if pair_id:
            subprocess.run(['xcrun', 'simctl', 'unpair', pair_id], check=False, timeout=30)
        for udid in reversed(created):
            subprocess.run(['xcrun', 'simctl', 'delete', udid], check=False, timeout=30)


if __name__ == '__main__':
    try:
        main()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(getattr(exc, 'stdout', '') or '', file=sys.stderr)
        print(getattr(exc, 'stderr', '') or '', file=sys.stderr)
        raise
