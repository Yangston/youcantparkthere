#!/usr/bin/env python3
"""Assemble an offline native screenshot report. No credentials or live user data."""
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ('index.html', 'styles.css', 'logic.js', 'app.js')


def catalog():
    return json.loads((ROOT / 'preview/fixtures.json').read_text(encoding='utf-8'))


def expected_state(scenario, fixtures=None):
    fixtures = fixtures or catalog()
    stations = fixtures['stations'] if scenario['data'] and not scenario.get('empty') else []
    counts = []
    for original in stations:
        station = {**original, **scenario.get('overrides', {}).get(original['id'], {})}
        operational = station['installed'] and station['returning' if scenario['mode'] == 'docks' else 'renting']
        field = 'electricBikes' if scenario['mode'] == 'bikes' and scenario.get('bikeFilter') == 'electric' else scenario['mode']
        counts.append(station.get(field) if operational and -60 <= scenario['age'] <= 120 else None)
    return {'scenario': scenario['id'], 'demo': True, 'mode': scenario['mode'],
            'riding': scenario['riding'], 'screen': scenario['page'] if scenario['page'] in ('settings', 'detail') else 'map',
            'bikeFilter': scenario.get('bikeFilter', 'all'),
            'counts': counts}


def validate_state(value, scenario):
    expected = expected_state(scenario)
    if value != expected:
        raise ValueError(f"Preview state mismatch for {scenario['id']}: expected {expected}, got {value}")


def git_value(*args):
    try:
        return subprocess.check_output(['git', *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return 'unknown'


def write_viewer(output, manifest):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    for name in ASSETS:
        shutil.copyfile(ROOT / 'preview' / name, output / name)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    baseline_path = output / 'baseline/manifest.json'
    baseline = None
    if baseline_path.is_file() and baseline_path.resolve().is_relative_to(output.resolve()):
        baseline = json.loads(baseline_path.read_text(encoding='utf-8'))
    payload = json.dumps({'report': manifest, 'fixtures': catalog(), 'baseline': baseline}, ensure_ascii=True).replace('<', '\\u003c')
    (output / 'report.js').write_text('window.PARK_DATA = ' + payload + ';\n', encoding='utf-8')


def build_report(build=None):
    build = Path(build or ROOT / 'build')
    output = build / 'preview'
    images = output / 'screenshots'
    images.mkdir(parents=True, exist_ok=True)
    capture_path = build / 'capture.json'
    capture = json.loads(capture_path.read_text()) if capture_path.exists() else {}
    entries = []
    for scenario in catalog()['scenarios']:
        name = scenario['id']
        state_path, png = build / f'preview-{name}.json', build / f'preview-{name}.png'
        entry = {key: scenario[key] for key in ('id', 'title', 'group', 'description')}
        entry.update(status='missing', file=None)
        if state_path.exists() and png.exists():
            try:
                state = json.loads(state_path.read_text())
                validate_state(state, scenario)
                if not png.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
                    raise ValueError('Invalid screenshot')
                shutil.copyfile(png, images / f'{name}.png')
                entry.update(status='captured', file=f'screenshots/{name}.png', state=state)
            except (ValueError, OSError) as error:
                entry.update(status='failed', error=str(error))
        entries.append(entry)
    sha = os.environ.get('GITHUB_SHA') or git_value('rev-parse', 'HEAD')
    repository = os.environ.get('GITHUB_REPOSITORY', 'Yangston/youcantparkthere')
    run_id = os.environ.get('GITHUB_RUN_ID')
    manifest = {'schema': 1, 'sha': sha,
                'branch': os.environ.get('GITHUB_HEAD_REF') or os.environ.get('GITHUB_REF_NAME') or git_value('branch', '--show-current'),
                'runURL': f'https://github.com/{repository}/actions/runs/{run_id}' if run_id else None,
                'device': capture.get('device', 'No native capture'), 'runtime': capture.get('runtime', ''),
                'profile': capture.get('profile', 'unknown'), 'capturedAt': capture.get('capturedAt'),
                'checks': {name: os.environ.get(name.upper(), 'not-run') for name in ('helpers', 'core', 'compile', 'archive', 'smoke')},
                'entries': entries}
    write_viewer(output, manifest)
    print(f'Preview: {output / "index.html"} ({sum(e["status"] == "captured" for e in entries)}/{len(entries)} native captures)')
    return manifest


if __name__ == '__main__':
    build_report()
