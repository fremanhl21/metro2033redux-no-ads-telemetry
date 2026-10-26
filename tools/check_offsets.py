#!/usr/bin/env python3
"""Shows where the patch bytes land in your own copy of the game DLLs.

    pip install pefile capstone
    python tools/check_offsets.py "C:\\...\\steamapps\\common\\Metro 2033 Redux"

For each patched location it prints the exported function that contains it, the file
offset, the bytes before/after and (with capstone) the disassembly. The game DLLs are
not part of this repository; the script only reads them.
"""
import hashlib
import os
import sys

import pefile

try:
    import capstone
    MD = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
except ImportError:
    MD = None

# Same data as in src/NoAdsTelemetry.ps1
TARGETS = {
    'pros.sdk.x64.dll': {
        'orig': '583c3e510474b8a644879481be7d8900a0b2d5110eb2647b2a53cd645fdaa7ee',
        'patches': [(0x18E0, '7410', '9090'), (0xAA40, '405556415441', 'B864000000C3')],
    },
    'uTelemetry.dll': {
        'orig': 'f54ec60e0eeef28a906b08a96ed5296d7b48bf65c9061cabec21d974695e8307',
        'patches': [(0x5C0, '48894C', '33C0C3')],
    },
}


def disasm(code, addr, count=16):
    if not MD:
        return
    for i, ins in enumerate(MD.disasm(code, addr)):
        print(f'      {ins.address:#x}  {ins.bytes.hex():<16} {ins.mnemonic} {ins.op_str}')
        if i + 1 >= count or ins.mnemonic == 'ret':
            break


def main(game_dir):
    for name, t in TARGETS.items():
        path = os.path.join(game_dir, name)
        data = open(path, 'rb').read()
        h = hashlib.sha256(data).hexdigest()
        print(f'{name}\n  SHA-256 {h} ({"original from the Next-Gen Update" if h == t["orig"] else "NOT the expected original"})')
        pe = pefile.PE(data=data)
        base = pe.OPTIONAL_HEADER.ImageBase
        exports = sorted((s.address, s.name.decode()) for s in pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name)
        for off, old, new in t['patches']:
            rva = pe.get_rva_from_offset(off)
            fn = max((e for e in exports if e[0] <= rva), default=(0, '?'))
            print(f'  file offset {off:#x} = RVA {rva:#x} = {fn[1]} + {rva - fn[0]:#x}')
            print(f'    bytes now: {data[off:off + len(old) // 2].hex().upper()}  expected original: {old}  patched: {new}')
            fo = pe.get_offset_from_rva(fn[0])
            print('    original code of the function:')
            disasm(data[fo:fo + 0x40], base + fn[0])
            patched = bytearray(data)
            patched[off:off + len(new) // 2] = bytes.fromhex(new)
            print('    after the patch:')
            disasm(bytes(patched[fo:fo + 0x40]), base + fn[0])
        print()


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
