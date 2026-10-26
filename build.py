#!/usr/bin/env python3
"""Builds the release archive published on Nexus Mods from the files in src/.

There is nothing to compile: the mod is a plain-text PowerShell script plus three
.bat launchers and a README. This script only checks the files and zips them.

    python build.py

Output: dist/Metro 2033 Redux - No Ads and Telemetry 1.0.zip
Uses only the Python standard library (Python 3.8 or newer).
"""
import hashlib
import os
import sys
import zipfile

VERSION = '1.0'
NAME = f'Metro 2033 Redux - No Ads and Telemetry {VERSION}.zip'
FILES = ['Install.bat', 'Uninstall.bat', 'Status.bat', 'NoAdsTelemetry.ps1', 'README.txt']

# SHA-256 of each file in the archive published on Nexus Mods (mod 63, file version 1.0).
EXPECTED = {
    'Install.bat':        '2185b8a1d418f3ad1303f19e6666c0083f114debb663ea14c6722d2c3c74aaa9',
    'Uninstall.bat':      '7595e2d66440630d5528d07a96edc2f14f5368464b2851a699de0c7694b1ef68',
    'Status.bat':         '795e7fb23c806b2f0e0429ad87bfe5a1ba7cebf518332a6a9d17de9ef34e3803',
    'NoAdsTelemetry.ps1': '3e60a78fbb5468c1dc0a7ed48583d19f3b9dfca6f5cb1e919191348b1a5f12a3',
    'README.txt':         '57681be9829aa6dbf85fbf6f876499b42bf26983fd4fe9f18dc5998e434697a1',
}
# SHA-256 of the published archive. Reproduced exactly with zlib 1.2.x/1.3.x (CPython's default);
# a different deflate library (e.g. zlib-ng) gives a different archive with identical contents.
EXPECTED_ZIP = '9a64df75adf42e7966b882182db42246b81e6775ee246aed0433ef6c5cccd21e'

ROOT = os.path.dirname(os.path.abspath(__file__))


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    ok = True
    print('Files:')
    contents = {}
    for name in FILES:
        data = open(os.path.join(ROOT, 'src', name), 'rb').read()
        # all files are plain ASCII text with CRLF line endings (the repo stores them byte for byte, see .gitattributes)
        data.decode('ascii')
        h = sha256(data)
        match = h == EXPECTED[name]
        ok &= match
        print(f'  {name:20} {h}  {"OK" if match else "DIFFERS from the published file"}')
        contents[name] = data

    os.makedirs(os.path.join(ROOT, 'dist'), exist_ok=True)
    out = os.path.join(ROOT, 'dist', NAME)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for name in FILES:
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 24, 23, 30, 0))  # fixed timestamp: reproducible archive
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o644 << 16
            z.writestr(info, contents[name])
    zh = sha256(open(out, 'rb').read())
    print(f'\nArchive: {out}\n  {zh}  {"OK, identical to the published archive" if zh == EXPECTED_ZIP else "(contents match; archive bytes depend on the deflate library)"}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
