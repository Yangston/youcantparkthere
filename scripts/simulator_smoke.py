#!/usr/bin/env python3
"""Capture real SwiftUI screens on a disposable paired Watch simulator.

Assert in-app routes and fixture state; never claim OS widget delivery, sensor or
physical-device validation. See docs/DEVELOPMENT.md for coverage and usage.
"""
import argparse
from datetime import datetime, timezone
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from preview_report import catalog, validate_state

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
BUNDLE = 'com.yangston.youcantparkthere.watchkitapp'


def run(*args: str, timeout: int = 90, quiet: bool = False) -> str:
    print('+ ' + ' '.join(args), flush=True)
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=timeout)
    if result.stdout and not quiet:
        print(result.stdout, flush=True)
    if result.stderr:
        print(result.stderr, flush=True)
    return result.stdout


def runtime_version(runtime: str) -> tuple[int, ...]:
    match = re.search(r'(?:watchOS|iOS)-(\d+(?:-\d+)*)$', runtime)
    return tuple(map(int, match.group(1).split('-'))) if match else (0,)


def create_device(name: str, template: dict, runtime: str) -> str:
    output = run('xcrun', 'simctl', 'create', name,
                 template.get('deviceTypeIdentifier') or template['name'], runtime).strip()
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', output):
        raise RuntimeError(f'Expected a simulator UDID, got {output!r}')
    return output


def activate_pair(pair_id: str) -> None:
    try:
        run('xcrun', 'simctl', 'pair_activate', pair_id)
    except subprocess.CalledProcessError as exc:
        message = (exc.stdout or '') + (exc.stderr or '')
        if exc.returncode != 37 or 'This pair is already active.' not in message:
            raise
        print('Pair was already activated by simctl pair.', flush=True)


def boot_if_needed(udid: str) -> None:
    # Fresh paired runtimes can spend minutes migrating system data. Only retry
    # this read-only inventory timeout; never retry a crash or state mismatch.
    for attempt in range(2):
        try:
            devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', '--json', timeout=180, quiet=True))['devices']
            break
        except subprocess.TimeoutExpired:
            if attempt: raise
            print('Simulator inventory timed out during startup; retrying once.', flush=True)
    device = next(item for items in devices.values() for item in items if item['udid'] == udid)
    if device['state'] == 'Shutdown':
        run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=240)


def process_id(output: str) -> int:
    match = re.search(r':\s*(\d+)\s*$', output.strip())
    if not match or int(match.group(1)) <= 0:
        raise RuntimeError('Simulator did not report a valid launched process ID.')
    return int(match.group(1))


def finish_launch(watch_id: str, pid: int) -> None:
    # A crash before our intentional shutdown must remain a failure.
    os.kill(pid, 0)
    run('xcrun', 'simctl', 'terminate', watch_id, BUNDLE)
    deadline = time.monotonic() + 15
    while True:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
        if time.monotonic() >= deadline:
            raise RuntimeError('Simulator app did not exit after termination.')
        time.sleep(0.1)
    # Let watchOS disconnect the previous scene before requesting another one.
    # Combined --terminate-running-process relaunches can be refused by Carousel.
    time.sleep(1)


def validate_report(report: dict, mode: str) -> None:
    expected = {'url': f'youcantparkthere://{mode}', 'accepted': True, 'demo': True,
                'mode': 'bikes' if mode == 'bikes' else 'docks', 'cycling': False, 'screen': 'map'}
    if mode not in ('docks', 'bikes', 'ride') or report != expected:
        raise RuntimeError(f'Route state mismatch: expected {expected}, got {report}')


def exercise_route(watch_id: str, data_dir: Path, mode: str) -> None:
    report = data_dir / 'Library/Caches/simulator-smoke.json'
    report.unlink(missing_ok=True)  # A report left by an earlier launch cannot pass this test.
    output = run('xcrun', 'simctl', 'launch', watch_id,
                 BUNDLE, '--demo', '--smoke-url', f'youcantparkthere://{mode}')
    pid = process_id(output)
    deadline = time.monotonic() + 45
    while not report.exists():
        os.kill(pid, 0)  # Fail immediately if the app crashed; never retry application crashes.
        if time.monotonic() >= deadline:
            raise RuntimeError(f'No in-app state report for {mode}; launch alone is not success.')
        time.sleep(0.5)
    validate_report(json.loads(report.read_text()), mode)
    time.sleep(3)
    os.kill(pid, 0)
    (BUILD / f'demo-{mode}.json').write_text(report.read_text())
    run('xcrun', 'simctl', 'io', watch_id, 'screenshot', str(BUILD / f'demo-{mode}.png'))
    finish_launch(watch_id, pid)
    print(f'PASS: {mode} route reached the expected app state and stayed alive.', flush=True)


def cleanup(*args: str) -> None:
    # Cleanup must not replace the original test failure with a shutdown error.
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=30)
        if result.returncode:
            print(f'Cleanup warning: {args}: {result.stderr.strip()}', file=sys.stderr)
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f'Cleanup warning: {exc}', file=sys.stderr)


def exercise_preview(watch_id: str, data_dir: Path, scenario: dict) -> None:
    report = data_dir / 'Library/Caches/preview-state.json'
    report.unlink(missing_ok=True)
    output = run('xcrun', 'simctl', 'launch', watch_id,
                 BUNDLE, '--preview-scenario', scenario['id'])
    pid = process_id(output)
    deadline = time.monotonic() + 45
    while not report.exists():
        os.kill(pid, 0)
        if time.monotonic() >= deadline:
            raise RuntimeError(f"Missing state report for {scenario['id']}")
        time.sleep(0.5)
    validate_state(json.loads(report.read_text()), scenario)
    time.sleep(3)  # Allow SwiftUI sheet presentation/layout to settle.
    os.kill(pid, 0)
    (BUILD / f"preview-{scenario['id']}.json").write_text(report.read_text())
    run('xcrun', 'simctl', 'io', watch_id, 'screenshot', str(BUILD / f"preview-{scenario['id']}.png"))
    finish_launch(watch_id, pid)
    print(f"PASS: preview {scenario['id']} state and process survival.", flush=True)


def watch_size(device: dict) -> int:
    match = re.search(r'(\d+)mm', device['name'])
    return int(match.group(1)) if match else 45


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=('compact', 'large'), default='compact')
    args = parser.parse_args()
    BUILD.mkdir(exist_ok=True)
    # Repeated local runs must not reuse screenshots from a failed/newer capture.
    for pattern in ('preview-*.png', 'preview-*.json', 'demo-*.png', 'demo-*.json', 'capture.json'):
        for path in BUILD.glob(pattern): path.unlink()
    app = BUILD / 'DerivedData/Build/Products/Debug-watchsimulator/ParkWatch.app'
    if not app.is_dir():
        raise RuntimeError(f'Missing simulator build: {app}')
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json', quiet=True))['devices']
    watches = [(runtime, item) for runtime, items in devices.items() if 'watchOS' in runtime
               for item in items if item.get('isAvailable') and 'Apple Watch' in item['name']]
    phones = [(runtime, item) for runtime, items in devices.items() if '.iOS-' in runtime
              for item in items if item.get('isAvailable') and item['name'].startswith('iPhone')]
    if not watches or not phones:
        raise RuntimeError('The launch check requires both watchOS and iOS simulator runtimes.')
    latest = max(runtime_version(item[0]) for item in watches)
    candidates = [item for item in watches if runtime_version(item[0]) == latest]
    pick = min if args.profile == 'compact' else max
    watch_runtime, watch = pick(candidates, key=lambda item: (watch_size(item[1]), item[1]['name']))
    phone_runtime, phone = max(phones, key=lambda item: (
        runtime_version(item[0]) == runtime_version(watch_runtime), runtime_version(item[0]),
        tuple(map(int, re.findall(r'\d+', item[1]['name']))) or (0,)))
    print(f"Smoke pair: {watch['name']} / {watch_runtime} + {phone['name']} / {phone_runtime}", flush=True)
    (BUILD / 'capture.json').write_text(json.dumps({'device': watch['name'], 'runtime': watch_runtime,
        'profile': args.profile, 'capturedAt': datetime.now(timezone.utc).isoformat()}))
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
        data_dir = Path(run('xcrun', 'simctl', 'get_app_container', watch_id, BUNDLE, 'data').strip())
        for mode in ('docks', 'bikes', 'ride'):
            exercise_route(watch_id, data_dir, mode)
        for scenario in catalog()['scenarios']:
            exercise_preview(watch_id, data_dir, scenario)
        print('PASS: install, launch, process survival, and three in-app routing assertions.')
        print('NOT TESTED: OS delivery from a real complication/Siri, GPS, or background wrist-raise behavior.')
    except Exception:
        if 'watch_id' in locals():
            try:
                diagnostic = run('xcrun', 'simctl', 'spawn', watch_id, 'log', 'show', '--style', 'compact',
                    '--last', '2m', '--predicate', 'process == "ParkWatch" OR process == "Carousel"',
                    timeout=30, quiet=True)
                (BUILD / 'simulator-diagnostics.log').write_text(diagnostic)
            except (OSError, subprocess.SubprocessError) as error:
                print(f'Could not collect simulator diagnostics: {type(error).__name__}', file=sys.stderr)
        raise
    finally:
        for udid in reversed(created):
            cleanup('xcrun', 'simctl', 'shutdown', udid)
        if pair_id:
            cleanup('xcrun', 'simctl', 'unpair', pair_id)
        for udid in reversed(created):
            cleanup('xcrun', 'simctl', 'delete', udid)


if __name__ == '__main__':
    try:
        main()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(getattr(exc, 'stdout', '') or '', file=sys.stderr)
        print(getattr(exc, 'stderr', '') or '', file=sys.stderr)
        raise
