METRO LAST LIGHT REDUX - NO ADS AND TELEMETRY 1.0
For the Next-Gen Update (PC: Steam, GOG and Epic)
by conjuntovazio

WHAT IT DOES
The Next-Gen Update added two online services to the game:
- PROS, Deep Silver's online service (pros.sdk.x64.dll). It draws the tile in the
  top-right corner of the main menu and loading screens (a promo banner with a QR
  code, or the game art with "Access DSA"), links the game to a Deep Silver Account
  and sends its own telemetry.
- The game's telemetry service (uTelemetry.dll, telemetry.deeparc.net).

On GOG the ad tile does not appear, because this build of PROS only signs in through
Steam or Epic accounts, but PROS still starts and the telemetry is active.

This mod makes both services fail at startup, through error paths the game already
handles. The ad tile is gone and no telemetry is sent. No firewall, hosts file or
DNS blocking is needed.

What you lose: only the Deep Silver Account link, the ad tile and its QR code.
The campaign, saves and achievements do not depend on these services.

INSTALL
1. Close the game.
2. Right-click the downloaded zip > Extract All... (any folder is fine).
3. Open the extracted folder and double-click Install.bat.
   - It finds the game by itself: Steam (every library, on any drive), GOG, Epic
     and the usual game folders.
   - If it can't, a window opens so you can pick the game folder. To see where the
     game is: in Steam, right-click the game > Manage > Browse local files; in GOG
     Galaxy, open the game > Manage installation > Show folder.
   - If Windows shows "Windows protected your PC", click More info > Run anyway.
     To avoid that message: before extracting, right-click the zip > Properties >
     tick "Unblock" > OK.
   - If it says "access denied", right-click Install.bat > Run as administrator.
4. Start the game normally.
The original DLLs are backed up in <game folder>\NoAdsTelemetry_backup.

UNINSTALL
- Double-click Uninstall.bat. It puts the original bytes back, checks the SHA-256 and
  deletes the backup.
- Or verify the game files: in Steam, right-click the game > Properties > Installed
  Files > Verify integrity of game files; in GOG Galaxy, open the game > Manage
  installation > Verify / Repair.

STATUS
- Status.bat shows whether each file is original, patched or an unknown version.
  It changes nothing.

AFTER A GAME UPDATE OR "VERIFY INTEGRITY"
- Steam or GOG Galaxy may put the original DLLs back. Run Install.bat again.
- If an update changes the DLLs, Install.bat reports "unknown version" and changes
  nothing. Wait for an updated version of this mod.

ANTIVIRUS
This mod contains no programs (.exe or .dll), only plain text files you can open in
Notepad. Install.bat starts Windows PowerShell with NoAdsTelemetry.ps1, and that
script:
- does not connect to the internet;
- does not ask for administrator rights or change Windows settings;
- does not change metro.exe or any file outside the game folder;
- only writes to pros.sdk.x64.dll, uTelemetry.dll and the NoAdsTelemetry_backup
  folder, and only if each DLL is exactly the known version (SHA-256 check).
Some antivirus programs distrust any .bat that starts PowerShell or any tool that
edits a DLL. If yours blocks it, that is a false positive: read the script, and
you can check the zip on virustotal.com.

HOW IT WORKS
No game files are included. The script changes a few bytes in your own two DLLs:

  pros.sdk.x64.dll  offset 0x18E0  74 10             -> 90 90
                    prosdk_init always returns the SDK's own error code 0x6C
                    offset 0xAA40  40 55 56 41 54 41 -> B8 64 00 00 00 C3
                    prosdk_banner_get_banner_spaces returns error 0x64 (no banners)
  uTelemetry.dll    offset 0x5C0   48 89 4C          -> 33 C0 C3
                    initialize_telemetry_resources returns 0 (failed)

The SHA-256 of each file is checked before and after the change. Any other version
of a file (for example, after a future game update) is left untouched.

FAQ
- The telemetry consent screen may still appear on the first launch. With this mod
  nothing is sent either way.
- Works with other mods, translations and texture packs: only these two DLLs are
  touched.
- Metro 2033 Redux uses the same two DLLs; it has its own version of this mod:
  https://www.nexusmods.com/metro2033redux/mods/63
- The Epic version is not tested. The script only works on the exact file versions
  above; if yours differ, it says so and changes nothing (run Status.bat to check).

REQUIREMENTS
- Metro Last Light Redux for PC with the Next-Gen Update. Tested on GOG.
- Windows 10 or 11 (uses the built-in Windows PowerShell).

FILES
  Install.bat           apply the change
  Uninstall.bat         restore the original files
  Status.bat            show the state of each file
  NoAdsTelemetry.ps1    the script that does the work (plain text)
  README.txt            this file

Metro Last Light Redux (c) 4A Games / Deep Silver. Fan-made; not affiliated with
4A Games, Deep Silver or Plaion.
