#!/usr/bin/env python3
"""Package reviewed native captures and editable listing material; never submit."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ('docks', 'bikes', 'favorites', 'station')


def validate_listing(listing, description):
    for key, limit in [('name', 30), ('subtitle', 30), ('keywords', 100), ('promotional_text', 170)]:
        if not listing.get(key) or len(listing[key]) > limit:
            raise ValueError(f'{key} must contain 1 to {limit} characters')
    if not description or len(description) > 4000:
        raise ValueError('description must contain 1 to 4000 characters')


def verify_captures(preview, expected_sha):
    manifest = json.loads((preview / 'manifest.json').read_text(encoding='utf-8'))
    if manifest['sha'] != expected_sha:
        raise ValueError('Native capture commit does not match the release commit')
    if any(manifest['checks'].get(k) != 'success' for k in ('helpers', 'core', 'compile', 'archive', 'smoke')):
        raise ValueError('Native validation has not passed')
    files = []
    for ident in SCENARIOS:
        entry = next((e for e in manifest['entries'] if e['id'] == ident), {})
        if entry.get('status') != 'captured' or entry.get('file') != f'screenshots/{ident}.png':
            raise ValueError(f'Missing native capture: {ident}')
        path = preview / entry['file']
        content = path.read_bytes()
        if content[:8] != b'\x89PNG\r\n\x1a\n' or len(content) < 24:
            raise ValueError(f'Invalid PNG: {ident}')
        if struct.unpack('!II', content[16:24]) != (422, 514):
            raise ValueError('Use consistent native 422 x 514 Apple Watch Ultra 3 captures')
        files.append((ident, path, hashlib.sha256(content).hexdigest()))
    return manifest, files


def write_site(folder, listing, policy):
    folder.mkdir(parents=True, exist_ok=True)
    esc = html.escape
    email = listing.get('support_email')
    contact = (f'<a href="mailto:{esc(email, quote=True)}">{esc(email)}</a>' if email
               else '<strong>Public support email pending.</strong> Use the <a href="https://github.com/Yangston/youcantparkthere/issues">project issue tracker</a> for now.')
    draft = '' if email else '<aside>Draft release material: add a public support email before publishing.</aside>'
    css = 'body{font:18px/1.6 system-ui,sans-serif;max-width:760px;margin:0 auto;padding:32px 22px;background:#f8faf8;color:#18211b}header{display:flex;gap:18px;align-items:center}img{width:82px;height:82px}h1{line-height:1.15}h2{font-size:1.3em;margin-top:2em}a{color:#006638}nav{margin:24px 0}aside{padding:16px;border:2px solid #9b5700}footer{margin-top:48px;border-top:1px solid #bdc9c0;padding-top:16px;font-size:.85em}'
    def page(title, body):
        return f'<!doctype html><html lang="en-CA"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)} - You Can\'t Park There</title><style>{css}</style><header><img src="icon.png" alt="Green parking sign"><h1>You Can\'t Park There</h1></header><nav><a href="index.html">Support</a> &middot; <a href="privacy.html">Privacy policy</a></nav>{draft}<main>{body}</main><footer>Independent app. Not affiliated with Bike Share Toronto or the Toronto Parking Authority. <a href="https://open.toronto.ca/open-data-licence/">Contains information licensed under the Open Government Licence - Toronto.</a></footer></html>'
    support = f'''<h2>Bike Share Toronto, on your Apple Watch</h2><p>Find available bikes and empty docks, save favourite stations, and check update times from your wrist. Apple Watch with watchOS 10 or later. Toronto coverage only.</p><h2>Contact support</h2><p>{contact}</p><p>Include the app version, watchOS version, Watch model and a description of the issue. Do not send passwords or precise location history. Public issues are visible to everyone.</p><h2>Common questions</h2><h3>Why is there no iPhone app icon?</h3><p>This is a watch-only app. Install it through the App Store or, for an invited beta, TestFlight on your paired iPhone.</p><h3>Why do counts show a dash?</h3><p>The count is unknown, stale or unavailable. A fresh zero means no inventory. An Internet connection is needed for updated station data.</p><h3>How do I reach Settings?</h3><p>Swipe left across the bottom controls or page dots. Swipe right to return. Drag above the controls to move the map.</p><h3>How do I stop automatic cycling?</h3><p>Turn Automatic cycling off in Settings. It stops background navigation immediately. Detection is optional and cannot start from a closed app.</p><h3>Can I reserve a bike or park a car?</h3><p>No. The app only shows Bike Share Toronto bike and dock availability; it does not reserve inventory or provide car parking.</p>'''
    privacy = f'<h2>Privacy policy</h2><p>Updated {esc(policy["updated"])}</p>'
    privacy += ''.join(f'<h3>{esc(s["title"])}</h3><p>{esc(s["body"])}</p>' for s in policy['sections'])
    privacy += f'<h3>Contact</h3><p>{contact}</p><p>Service policies: <a href="https://www.apple.com/legal/privacy/data/en/apple-maps/">Apple Maps</a>; <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">GitHub</a>.</p>'
    (folder / 'index.html').write_text(page('Support', support), encoding='utf-8')
    (folder / 'privacy.html').write_text(page('Privacy policy', privacy), encoding='utf-8')
    (folder / '.nojekyll').touch()


def prepare(preview, output, sha):
    source = ROOT / 'app-store'
    listing = json.loads((source / 'listing.json').read_text(encoding='utf-8'))
    description = (source / 'description.txt').read_text(encoding='utf-8')
    policy = json.loads((source / 'privacy-policy.json').read_text(encoding='utf-8'))
    validate_listing(listing, description)
    manifest, files = verify_captures(preview, sha)
    icon = ROOT / 'WatchApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
    if not icon.is_file():
        raise ValueError('Run python scripts/make_assets.py first')
    output.mkdir(parents=True, exist_ok=True)
    for name in ('listing.json', 'description.txt', 'review-notes.txt', 'privacy-policy.json'):
        shutil.copyfile(source / name, output / name)
    shots = output / 'screenshots/en-CA'
    shots.mkdir(parents=True, exist_ok=True)
    for index, (ident, path, _) in enumerate(files, 1):
        shutil.copyfile(path, shots / f'{index:02d}-{ident}.png')
    write_site(output / 'site', listing, policy)
    shutil.copyfile(icon, output / 'app-icon-1024.png')
    shutil.copyfile(icon, output / 'site/icon.png')
    provenance = {k: manifest[k] for k in ('sha', 'device', 'runtime', 'capturedAt', 'runURL', 'checks')}
    provenance['screenshots'] = [{'scenario': ident, 'sha256': digest} for ident, _, digest in files]
    provenance['sampleAvailability'] = True
    provenance['websiteReady'] = bool(listing.get('support_email'))
    (output / 'provenance.json').write_text(json.dumps(provenance, indent=2), encoding='utf-8')
    (output / 'README.txt').write_text('Prepared App Store material, not a submission. Screenshots are unedited native simulator captures with labelled sample availability. Review docs/APP_STORE_RELEASE.md before submitting. Publish and verify the support/privacy URLs; supplying proposed URLs in listing.json does not publish a site. Do not upload provenance.json to the product page.\n', encoding='utf-8')
    print(f'Prepared {output} from {sha[:7]}; no submission or website deployment performed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', type=Path, default=ROOT / 'build/preview')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/app-store')
    parser.add_argument('--sha')
    parser.add_argument('--site-only', action='store_true')
    args = parser.parse_args()
    if args.site_only:
        listing = json.loads((ROOT / 'app-store/listing.json').read_text(encoding='utf-8'))
        policy = json.loads((ROOT / 'app-store/privacy-policy.json').read_text(encoding='utf-8'))
        if not listing.get('support_email'):
            parser.error('A public support email is required before publishing the site')
        write_site(args.output, listing, policy)
        shutil.copyfile(ROOT / 'WatchApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png', args.output / 'icon.png')
    else:
        if not args.sha:
            parser.error('--sha is required for a native screenshot package')
        prepare(args.preview, args.output, args.sha)
