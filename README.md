# Metro Redux - No Ads and Telemetry

Source for the Nexus Mods releases "No Ads and Telemetry (Next-Gen Update)", by conjuntovazio:

| Game | Nexus Mods | Source |
|---|---|---|
| Metro 2033 Redux | [mod 63](https://www.nexusmods.com/metro2033redux/mods/63) | [`src/`](src) |
| Metro Last Light Redux | (Metro Last Light Redux page) | [`src-lastlight/`](src-lastlight) |

Both versions are the same script with game-specific names, Steam App ID (286690 / 287390) and folder search; both games ship the exact same two DLLs listed below.

The Next-Gen Update of the Metro Redux games (PC, 2026) added two online services:

- **PROS**, Deep Silver's online service (`pros.sdk.x64.dll`): the ad tile in the top-right corner of the menu and loading screens (promo banner, QR code, "Access DSA"), the Deep Silver Account link and its own telemetry.
- **The game's telemetry service** (`uTelemetry.dll`, telemetry.deeparc.net).

The mod makes both fail at startup, through error paths the game already handles.

## What is in the release

There is no compiled code. Each release archive contains only the plain-text files in [`src/`](src) (Metro 2033 Redux) or [`src-lastlight/`](src-lastlight) (Metro Last Light Redux):

| File | What it is |
|---|---|
| `NoAdsTelemetry.ps1` | The PowerShell script that does all the work |
| `Install.bat`, `Uninstall.bat`, `Status.bat` | One-line launchers: `powershell.exe -ExecutionPolicy Bypass -File NoAdsTelemetry.ps1 -Action install\|uninstall\|status` |
| `README.txt` | User instructions |

## Building the release archives

Nothing needs to be compiled; "building" only zips the files in `src/` and `src-lastlight/` with fixed timestamps.

1. Install Python 3.8 or newer (standard library only, no packages).
2. Run:
   ```
   python build.py              (both games)
   python build.py 2033         (Metro 2033 Redux only)
   python build.py lastlight    (Metro Last Light Redux only)
   ```
3. The archives are written to `dist/`. The script prints the SHA-256 of every file and of each archive and compares them with the published releases.

SHA-256 of the files in the published Metro 2033 Redux archive (version 1.0):

| File | SHA-256 |
|---|---|
| `Install.bat` | `2185b8a1d418f3ad1303f19e6666c0083f114debb663ea14c6722d2c3c74aaa9` |
| `Uninstall.bat` | `7595e2d66440630d5528d07a96edc2f14f5368464b2851a699de0c7694b1ef68` |
| `Status.bat` | `795e7fb23c806b2f0e0429ad87bfe5a1ba7cebf518332a6a9d17de9ef34e3803` |
| `NoAdsTelemetry.ps1` | `3e60a78fbb5468c1dc0a7ed48583d19f3b9dfca6f5cb1e919191348b1a5f12a3` |
| `README.txt` | `57681be9829aa6dbf85fbf6f876499b42bf26983fd4fe9f18dc5998e434697a1` |
| **Archive** | `9a64df75adf42e7966b882182db42246b81e6775ee246aed0433ef6c5cccd21e` |

SHA-256 of the files in the Metro Last Light Redux archive (version 1.0):

| File | SHA-256 |
|---|---|
| `Install.bat` | `8b9caa6a170d8c69b733302656258d4214e11beea410977ed5e68831dfba8481` |
| `Uninstall.bat` | `5f29a334dedb576c415f9b9730e47bf75bd7c997accb033bbe862397ca8167ac` |
| `Status.bat` | `3020996e3e3be568479a77404214194f51a1e4d5343b077687b450a5a6f4f001` |
| `NoAdsTelemetry.ps1` | `f80738f5bc45cef64ffe088eea5a70f06b9c6df2ddd9ca17cf424fba99b92e8a` |
| `README.txt` | `4f028f5892f4d8d3821de00afff093b744c5cfc7c7c833ff4ba9e8a3ee3b06ae` |
| **Archive** | `8f78cf1fff9d05f9b3a609f44fdfbe9afbd3fc64a122d3937f7cb7fe31c1a020` |

The archive hashes are reproduced exactly with CPython's usual zlib (1.2.x/1.3.x). With a different deflate library the archive bytes differ, but the file hashes above still match. The files are stored byte for byte (CRLF line endings, see `.gitattributes`).

The [GitHub Actions workflow](.github/workflows/build.yml) runs `build.py`, checks that both PowerShell scripts parse, and uploads the archives as an artifact on every push.

## What the script does

1. Finds the game folder: the folder it was extracted to, the Steam uninstall entry and every Steam library in `libraryfolders.vdf`, GOG and Epic install records, common game folders on each drive, or a folder picker. It only **reads** the registry.
2. Refuses to run while `metro.exe` is running.
3. For each of the two DLLs, checks the SHA-256. It continues only if the file is exactly the original from the Next-Gen Update (or already patched). Any other version is left untouched.
4. Copies the original to `<game folder>\NoAdsTelemetry_backup`, changes the bytes below, and checks the SHA-256 of the result.
5. `Uninstall.bat` writes the original bytes back, checks the SHA-256 and deletes the backup.

| File | Offset | Original | Patched | Effect |
|---|---|---|---|---|
| `pros.sdk.x64.dll` | `0x18E0` | `74 10` | `90 90` | In `prosdk_init`, the SDK-version check always fails, so the function returns its own error code `0x6C` and PROS never starts |
| `pros.sdk.x64.dll` | `0xAA40` | `40 55 56 41 54 41` | `B8 64 00 00 00 C3` | `prosdk_banner_get_banner_spaces` returns error `0x64` (no banners) |
| `uTelemetry.dll` | `0x5C0` | `48 89 4C` | `33 C0 C3` | `initialize_telemetry_resources` returns 0 (initialization failed); `create_telemetry_interface` then refuses to create the telemetry object |

Both games use the same DLL versions:

| DLL | SHA-256 original (Next-Gen Update) | SHA-256 patched |
|---|---|---|
| `pros.sdk.x64.dll` | `583c3e510474b8a644879481be7d8900a0b2d5110eb2647b2a53cd645fdaa7ee` | `ceebf87b27be1a431165be433d4e16a81b569fb6cb7c7c490d210e99e24d07dc` |
| `uTelemetry.dll` | `f54ec60e0eeef28a906b08a96ed5296d7b48bf65c9061cabec21d974695e8307` | `fb6a8fa9ba1e0b8db548f1be548fb6c7e36c14b81aaf2c7436f3017408598db6` |

To check where these bytes land in your own copy of the game, run [`tools/check_offsets.py`](tools/check_offsets.py) (`pip install pefile capstone`). It prints the exported function containing each offset and the disassembly before and after the patch. The game DLLs are not included in this repository.

## What it does not do

- No network access.
- Does not ask for administrator rights and does not elevate itself.
- No persistence: no services, scheduled tasks, startup entries or registry writes.
- Does not modify `metro.exe` or any file outside the game folder.
- Does not ship any game file.

Metro 2033 Redux and Metro Last Light Redux (c) 4A Games / Deep Silver. Fan-made; not affiliated with 4A Games, Deep Silver or Plaion.
