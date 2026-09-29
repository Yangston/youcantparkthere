#!/usr/bin/env python3
import os
import re
import sys

required = ('APP_STORE_CONNECT_ISSUER_ID', 'APP_STORE_CONNECT_KEY_IDENTIFIER',
            'APP_STORE_CONNECT_PRIVATE_KEY', 'CERTIFICATE_PRIVATE_KEY',
            'APPLE_TEAM_ID', 'APP_STORE_APP_ID')
missing = [name for name in required if not os.environ.get(name, '').strip()]
if missing:
    sys.exit('Missing configuration: ' + ', '.join(missing) + '. See docs/SETUP.md. Never paste private keys into issues or chat.')
if not re.fullmatch(r'[A-Z0-9]{10}', os.environ['APPLE_TEAM_ID']):
    sys.exit('APPLE_TEAM_ID must be your 10-character Apple team ID.')
if not os.environ['APP_STORE_APP_ID'].isdigit():
    sys.exit('APP_STORE_APP_ID must be the numeric App Store Connect app ID.')
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', os.environ.get('BUNDLE_ID', '')):
    sys.exit('BUNDLE_ID must be a valid reverse-DNS identifier.')
for name in ('APP_STORE_CONNECT_PRIVATE_KEY', 'CERTIFICATE_PRIVATE_KEY'):
    if 'PRIVATE KEY-----' not in os.environ[name]:
        sys.exit(name + ' must contain the complete PEM private key, not a filename or base64 string.')
print('Required signing settings are present. Apple permissions and certificate validity are checked during signing.')
