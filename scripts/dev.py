#!/usr/bin/env python3
"""Windows-friendly checks, local preview and unsigned native preview retrieval."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlsplit
import zipfile

from preview_report import ASSETS, ROOT, build_report, write_viewer

REPO = 'Yangston/youcantparkthere'
OUTPUT = ROOT / 'build/preview'


def gh(*args):
    cli = shutil.which('gh')
    if not cli:
        candidate = Path('C:/Program Files/GitHub CLI/gh.exe')
        cli = str(candidate) if candidate.exists() else None
    if not cli:
        raise RuntimeError('GitHub CLI is needed for capture/fetch. Install from https://cli.github.com and run gh auth login. Or download the preview artifact in Actions and use import.')
    return subprocess.check_output([cli, *args], text=True)


def validate_manifest(manifest):
    if manifest.get('schema') != 1 or not isinstance(manifest.get('entries'), list):
        raise ValueError('Not a supported native preview manifest')
    if not re.fullmatch(r'[a-f0-9]{40}', manifest.get('sha', '')):
        raise ValueError('Native preview must identify its source commit')
    seen = set()
    for entry in manifest['entries']:
        name = entry.get('id', '')
        if not re.fullmatch(r'[a-z0-9-]+', name) or name in seen:
            raise ValueError('Invalid or duplicate scenario identifier')
        seen.add(name)
        if entry.get('file') not in (None, f'screenshots/{name}.png'):
            raise ValueError('Invalid screenshot path')
        if entry.get('status') == 'captured' and not entry.get('file'):
            raise ValueError('Captured scenario has no image')


def import_folder(folder, output=OUTPUT):
    folder, output = Path(folder).resolve(), Path(output).resolve()
    if not (folder / 'manifest.json').is_file(): raise ValueError('Preview artifact is missing manifest.json')
    manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
    validate_manifest(manifest)
    images = {}
    for entry in manifest['entries']:
        if entry.get('file'):
            source = (folder / entry['file']).resolve()
            if not source.is_relative_to(folder): raise ValueError('Screenshot escapes preview folder')
            image = source.read_bytes()
            if len(image) > 15_000_000 or not image.startswith(b'\x89PNG\r\n\x1a\n'):
                raise ValueError('Invalid or oversized screenshot')
            images[entry['file']] = image
    # Validate every input first. Copy only data/images; never execute imported HTML/JS.
    (output / 'screenshots').mkdir(parents=True, exist_ok=True)
    for name, image in images.items(): (output / name).write_bytes(image)
    write_viewer(output, manifest)
    return manifest


def import_zip(path, output=OUTPUT):
    with tempfile.TemporaryDirectory() as temporary, zipfile.ZipFile(path) as archive:
        total = 0
        for item in archive.infolist():
            part = PurePosixPath(item.filename)
            if part.is_absolute() or '..' in part.parts or '\\' in item.filename or ':' in item.filename:
                raise ValueError('Unsafe archive path')
            if (item.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError('Archive symlinks are not allowed')
            total += item.file_size
            if total > 100_000_000: raise ValueError('Preview archive exceeds 100 MB')
            # The GitHub preview artifact has its manifest at the archive root.
            if item.filename != 'manifest.json' and not re.fullmatch(r'screenshots/[a-z0-9-]+\.png', item.filename):
                continue
            target = Path(temporary) / item.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(item))
        return import_folder(temporary, output)


class PreviewHandler(SimpleHTTPRequestHandler):
    """Only serve viewer assets and screenshots, never repository/private files."""
    def do_GET(self):
        path = unquote(urlsplit(self.path).path).lstrip('/') or 'index.html'
        allowed = {*ASSETS, 'manifest.json', 'report.js'}
        if path not in allowed and not re.fullmatch(r'(?:baseline/)?screenshots/[a-z0-9-]+\.png', path):
            self.send_error(404)
            return
        if not (Path(self.directory) / path).resolve().is_relative_to(Path(self.directory).resolve()):
            self.send_error(404)
            return
        if path in ASSETS:
            shutil.copyfile(ROOT / 'preview' / path, Path(self.directory) / path)
        if path == 'index.html':
            manifest = json.loads((Path(self.directory) / 'manifest.json').read_text(encoding='utf-8'))
            write_viewer(Path(self.directory), manifest)
        super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('check', help='Python + preview logic tests; Swift tests when installed')
    serve = commands.add_parser('preview', help='Local interaction sandbox and imported native gallery')
    serve.add_argument('--port', type=int, default=8765)
    load = commands.add_parser('import', help='Import a downloaded watch-preview-*.zip artifact')
    load.add_argument('archive', type=Path)
    baseline = commands.add_parser('baseline', help='Save an older preview ZIP for comparison without a browser folder picker')
    baseline.add_argument('archive', type=Path)
    capture = commands.add_parser('capture', help='Manually run unsigned CI for an already-pushed branch')
    capture.add_argument('--ref', required=True)
    fetch = commands.add_parser('fetch', help='Download a completed native preview with GitHub CLI')
    fetch.add_argument('--run', required=True, type=int)
    fetch.add_argument('--profile', choices=('compact', 'large'), default='compact')
    args = parser.parse_args()
    if args.command == 'check':
        subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'scripts/tests', '-v'], cwd=ROOT, check=True)
        subprocess.run(['node', '--test', 'preview/tests/logic.test.cjs'], cwd=ROOT, check=True)
        subprocess.run(['node', '--check', 'preview/app.js'], cwd=ROOT, check=True)
        if shutil.which('swift'):
            subprocess.run(['swift', 'test'], cwd=ROOT, check=True)
        else: print('Swift not installed locally. Native CI must pass before release; Swift tests were NOT run here.')
    elif args.command == 'import':
        result = import_zip(args.archive)
        print(f"Imported {result['sha'][:7]} / {result['device']}. Run: python scripts/dev.py preview")
    elif args.command == 'baseline':
        if not (OUTPUT / 'manifest.json').exists(): build_report()
        result = import_zip(args.archive, OUTPUT / 'baseline')
        current = json.loads((OUTPUT / 'manifest.json').read_text(encoding='utf-8'))
        write_viewer(OUTPUT, current)
        print(f"Saved baseline {result['sha'][:7]} / {result['device']}. Refresh the studio and select Use saved baseline.")
    elif args.command == 'capture':
        if not args.ref or args.ref.startswith('-'): raise ValueError('Invalid branch name')
        print(gh('workflow', 'run', 'build.yml', '--repo', REPO, '--ref', args.ref))
        print('Unsigned native preview requested. Only the pushed commit is used; no Watch/TestFlight upload occurs.')
    elif args.command == 'fetch':
        with tempfile.TemporaryDirectory() as directory:
            gh('run', 'download', str(args.run), '--repo', REPO, '--name', f'watch-preview-{args.profile}', '--dir', directory)
            result = import_folder(directory)
            print(f"Imported {result['sha'][:7]} / {result['device']}. Run: python scripts/dev.py preview")
    else:
        if not (OUTPUT / 'manifest.json').exists(): build_report()
        handler = partial(PreviewHandler, directory=str(OUTPUT))
        server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
        print(f'Preview studio: http://127.0.0.1:{args.port} (Ctrl+C to stop)', flush=True)
        try: server.serve_forever()
        except KeyboardInterrupt: pass
        finally: server.server_close()


if __name__ == '__main__':
    try: main()
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
