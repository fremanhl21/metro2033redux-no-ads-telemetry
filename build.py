#!/usr/bin/env python3
"""Builds the release archives published on Nexus Mods.

There is nothing to compile: each mod is a plain-text PowerShell script plus three
.bat launchers and a README. This script only checks the files and zips them.

    python build.py              (both games)
    python build.py 2033         (Metro 2033 Redux only)
    python build.py lastlight    (Metro Last Light Redux only)

Output: dist/<name>.zip. Uses only the Python standard library (Python 3.8 or newer).
"""
import hashlib
import os
import sys
import zipfile

FILES = ['Install.bat', 'Uninstall.bat', 'Status.bat', 'NoAdsTelemetry.ps1', 'README.txt']

# SHA-256 of each file in the archives published on Nexus Mods.
# 'zip' is the SHA-256 of the archive itself: reproduced exactly with zlib 1.2.x/1.3.x (CPython's
# default); a different deflate library (e.g. zlib-ng) gives different archive bytes with identical contents.
VARIANTS = {
    '2033': {
        'src': 'src',
        'name': 'Metro 2033 Redux - No Ads and Telemetry 1.0.zip',
        'date': (2026, 10, 24, 23, 30, 0),
        'files': {
            'Install.bat':        '2185b8a1d418f3ad1303f19e6666c0083f114debb663ea14c6722d2c3c74aaa9',
            'Uninstall.bat':      '7595e2d66440630d5528d07a96edc2f14f5368464b2851a699de0c7694b1ef68',
            'Status.bat':         '795e7fb23c806b2f0e0429ad87bfe5a1ba7cebf518332a6a9d17de9ef34e3803',
            'NoAdsTelemetry.ps1': '3e60a78fbb5468c1dc0a7ed48583d19f3b9dfca6f5cb1e919191348b1a5f12a3',
            'README.txt':         '57681be9829aa6dbf85fbf6f876499b42bf26983fd4fe9f18dc5998e434697a1',
        },
        'zip': '9a64df75adf42e7966b882182db42246b81e6775ee246aed0433ef6c5cccd21e',
    },
    'lastlight': {
        'src': 'src-lastlight',
        'name': 'Metro Last Light Redux - No Ads and Telemetry 1.0.zip',
        'date': (2026, 10, 27, 0, 30, 0),
        'files': {
            'Install.bat':        '8b9caa6a170d8c69b733302656258d4214e11beea410977ed5e68831dfba8481',
            'Uninstall.bat':      '5f29a334dedb576c415f9b9730e47bf75bd7c997accb033bbe862397ca8167ac',
            'Status.bat':         '3020996e3e3be568479a77404214194f51a1e4d5343b077687b450a5a6f4f001',
            'NoAdsTelemetry.ps1': 'f80738f5bc45cef64ffe088eea5a70f06b9c6df2ddd9ca17cf424fba99b92e8a',
            'README.txt':         '4f028f5892f4d8d3821de00afff093b744c5cfc7c7c833ff4ba9e8a3ee3b06ae',
        },
        'zip': '8f78cf1fff9d05f9b3a609f44fdfbe9afbd3fc64a122d3937f7cb7fe31c1a020',
    },
}

ROOT = os.path.dirname(os.path.abspath(__file__))


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def build(key):
    v = VARIANTS[key]
    ok = True
    print(f'[{key}] files in {v["src"]}/:')
    contents = {}
    for name in FILES:
        data = open(os.path.join(ROOT, v['src'], name), 'rb').read()
        # all files are plain ASCII text with CRLF line endings (stored byte for byte, see .gitattributes)
        data.decode('ascii')
        h = sha256(data)
        match = h == v['files'][name]
        ok &= match
        print(f'  {name:20} {h}  {"OK" if match else "DIFFERS from the published file"}')
        contents[name] = data
    os.makedirs(os.path.join(ROOT, 'dist'), exist_ok=True)
    out = os.path.join(ROOT, 'dist', v['name'])
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for name in FILES:
            info = zipfile.ZipInfo(name, date_time=v['date'])  # fixed timestamp: reproducible archive
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o644 << 16
            z.writestr(info, contents[name])
    zh = sha256(open(out, 'rb').read())
    note = ('OK, identical to the published archive' if zh == v['zip'] else
            '(contents match; archive bytes depend on the deflate library)' if v['zip'] else '')
    print(f'  archive: dist/{v["name"]}\n  {zh}  {note}\n')
    return ok


def main(args):
    keys = args or list(VARIANTS)
    results = [build(k) for k in keys]
    return 0 if all(results) else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
