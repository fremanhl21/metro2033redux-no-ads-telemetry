# Metro Last Light Redux - No Ads and Telemetry (Next-Gen Update)
# Patches the game's own DLLs in place. No game files are shipped with this mod.
# Every change is checked by SHA-256 before and after; unknown file versions are left untouched.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.
# It does not use the network, does not elevate itself, does not touch metro.exe and only writes to
# pros.sdk.x64.dll, uTelemetry.dll and the NoAdsTelemetry_backup folder inside the game folder.

param(
    [Parameter(Position = 0)][string]$GameDir = '',
    [ValidateSet('install', 'uninstall', 'status')][string]$Action = 'install'
)

$ErrorActionPreference = 'Stop'
$ModTitle = 'Metro Last Light Redux - No Ads and Telemetry 1.0'
$SteamAppId = '287390'
$BackupName = 'NoAdsTelemetry_backup'

# File versions from the Next-Gen Update (Metro 2033 Redux uses the same two DLLs).
$Targets = @(
    @{
        File    = 'pros.sdk.x64.dll'
        What    = 'Deep Silver online service (PROS): ad tile, QR code and "Access DSA" prompt'
        Orig    = '583c3e510474b8a644879481be7d8900a0b2d5110eb2647b2a53cd645fdaa7ee'
        Mod     = 'ceebf87b27be1a431165be433d4e16a81b569fb6cb7c7c490d210e99e24d07dc'
        Patches = @(
            # prosdk_init: always take the SDK's own "version mismatch" error exit (0x6C)
            @{ Off = 0x18E0; Old = '7410'; New = '9090' },
            # prosdk_banner_get_banner_spaces: return error 0x64, no banners
            @{ Off = 0xAA40; Old = '405556415441'; New = 'B864000000C3' }
        )
    },
    @{
        File    = 'uTelemetry.dll'
        What    = 'game telemetry service (telemetry.deeparc.net)'
        Orig    = 'f54ec60e0eeef28a906b08a96ed5296d7b48bf65c9061cabec21d974695e8307'
        Mod     = 'fb6a8fa9ba1e0b8db548f1be548fb6c7e36c14b81aaf2c7436f3017408598db6'
        Patches = @(
            # initialize_telemetry_resources: return 0 (initialization failed)
            @{ Off = 0x5C0; Old = '48894C'; New = '33C0C3' }
        )
    }
)

function Write-Line([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Get-HexBytes([string]$Hex) {
    $out = New-Object byte[] ([int]($Hex.Length / 2))
    for ($i = 0; $i -lt $out.Length; $i++) { $out[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return , $out
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-FileSha256([string]$Path) {
    return Get-BytesSha256 ([IO.File]::ReadAllBytes($Path))
}

function Test-GameDir([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir)) { return $false }
    try { return (Test-Path -LiteralPath (Join-Path $Dir 'metro.exe')) -and (Test-Path -LiteralPath (Join-Path $Dir 'pros.sdk.x64.dll')) }
    catch { return $false }
}

# Accepts the game folder itself, its parent (e.g. ...\steamapps\common) or a folder inside it.
function Resolve-GameDir([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir)) { return $null }
    $d = $Dir.Trim().Trim('"').TrimEnd('\', '/')
    if ($d -match '^[A-Za-z]:$') { $d += '\' }
    $tries = @($d)
    try { $tries += (Join-Path $d 'Metro Last Light Redux') } catch { }
    try { $p = Split-Path -Parent $d; if ($p) { $tries += $p; $pp = Split-Path -Parent $p; if ($pp) { $tries += $pp } } } catch { }
    foreach ($t in $tries) { if (Test-GameDir $t) { return $t } }
    return $null
}

function Get-RegValue([string]$Key, [string]$Name) {
    try { return (Get-ItemProperty -LiteralPath $Key -ErrorAction Stop).$Name } catch { return $null }
}

function Find-GameDirAuto {
    $cands = New-Object System.Collections.ArrayList
    # the folder this mod was extracted to
    [void]$cands.Add($PSScriptRoot)
    # Steam: uninstall entry
    foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App $SteamAppId",
                     "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App $SteamAppId")) {
        $v = Get-RegValue $k 'InstallLocation'; if ($v) { [void]$cands.Add($v) }
    }
    # Steam: every library folder (games installed on other drives)
    $steams = @((Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'),
                (Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath'),
                (Get-RegValue 'HKLM:\SOFTWARE\Valve\Steam' 'InstallPath')) | Where-Object { $_ }
    foreach ($s in $steams) {
        $libs = @($s)
        $vdf = Join-Path $s 'steamapps\libraryfolders.vdf'
        try {
            if (Test-Path -LiteralPath $vdf) {
                foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                    $libs += ($m.Groups[1].Value -replace '\\\\', '\')
                }
            }
        } catch { }
        foreach ($l in $libs) { [void]$cands.Add((Join-Path $l 'steamapps\common\Metro Last Light Redux')) }
    }
    # GOG Galaxy
    foreach ($root in @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games', 'HKLM:\SOFTWARE\GOG.com\Games')) {
        try {
            foreach ($g in (Get-ChildItem -LiteralPath $root -ErrorAction Stop)) {
                $p = Get-ItemProperty -LiteralPath $g.PSPath
                if ($p.gameName -like '*Last Light Redux*' -and $p.path) { [void]$cands.Add($p.path) }
            }
        } catch { }
    }
    # Epic Games Launcher
    try {
        $man = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        foreach ($f in (Get-ChildItem -LiteralPath $man -Filter '*.item' -ErrorAction Stop)) {
            try {
                $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
                if ($j.DisplayName -like '*Last Light Redux*' -and $j.InstallLocation) { [void]$cands.Add($j.InstallLocation) }
            } catch { }
        }
    } catch { }
    # usual folders on every drive
    try {
        foreach ($drv in (Get-PSDrive -PSProvider FileSystem -ErrorAction Stop)) {
            foreach ($rel in @('SteamLibrary\steamapps\common', 'Steam\steamapps\common', 'Program Files (x86)\Steam\steamapps\common',
                               'Program Files\Steam\steamapps\common', 'Games\Steam\steamapps\common', 'Games',
                               'GOG Games', 'Program Files (x86)\GOG Galaxy\Games', 'Program Files\Epic Games', 'Epic Games')) {
                [void]$cands.Add((Join-Path (Join-Path $drv.Root $rel) 'Metro Last Light Redux'))
            }
        }
    } catch { }
    foreach ($c in $cands) { if (Test-GameDir $c) { return $c.TrimEnd('\') } }
    return $null
}

function Select-GameDirDialog {
    # A folder picker is friendlier than typing a path. Returns '' if the window can't be shown.
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        while ($true) {
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = 'Select the Metro Last Light Redux folder (the one with metro.exe). Steam: right-click the game > Manage > Browse local files. GOG Galaxy: the game > Manage installation > Show folder.'
            $dlg.ShowNewFolderButton = $false
            if ($dlg.ShowDialog($owner) -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
            $d = Resolve-GameDir $dlg.SelectedPath
            if ($d) { return $d }
            [void][System.Windows.Forms.MessageBox]::Show($owner, "metro.exe was not found in:`n$($dlg.SelectedPath)`n`nPick the Metro Last Light Redux folder.", $ModTitle)
        }
    }
    catch { return '' }
}

function Find-GameDir {
    if ($GameDir) {
        $d = Resolve-GameDir $GameDir
        if ($d) { return $d }
        Write-Line "Not a Metro Last Light Redux folder: $GameDir" 'Yellow'
    }
    Write-Line 'Looking for the game (Steam, GOG, Epic and the usual folders)...'
    $d = Find-GameDirAuto
    if ($d) { return $d }
    Write-Host ''
    Write-Line 'Could not find the game folder automatically. A window will ask you to pick it.' 'Yellow'
    Write-Line 'Tip: Steam: right-click the game > Manage > Browse local files. GOG Galaxy: the game > Manage installation > Show folder.'
    $d = Select-GameDirDialog
    if ($d -ne '') { return $d }
    # no window available: ask in the console
    while ($true) {
        Write-Line 'Example: C:\Program Files (x86)\Steam\steamapps\common\Metro Last Light Redux'
        $t = Read-Host 'Paste the Metro Last Light Redux folder (the one with metro.exe) and press Enter, or just Enter to cancel'
        if ([string]::IsNullOrWhiteSpace($t)) { return $null }
        $d = Resolve-GameDir $t
        if ($d) { return $d }
        Write-Line "metro.exe was not found in: $t" 'Red'
    }
}

function Set-Bytes([byte[]]$Bytes, $Patches, [string]$Field, [string]$Expect) {
    foreach ($p in $Patches) {
        $exp = Get-HexBytes $p[$Expect]; $new = Get-HexBytes $p[$Field]
        for ($i = 0; $i -lt $exp.Length; $i++) {
            if ($Bytes[$p.Off + $i] -ne $exp[$i]) { throw ('unexpected bytes at 0x{0:X}' -f $p.Off) }
        }
        [Array]::Copy($new, 0, $Bytes, $p.Off, $new.Length)
    }
}

function Write-Checked([string]$Path, [byte[]]$Bytes, [string]$Hash) {
    if ((Get-BytesSha256 $Bytes) -ne $Hash) { throw 'patched result does not match the expected SHA-256' }
    $fi = New-Object IO.FileInfo $Path
    if ($fi.IsReadOnly) { $fi.IsReadOnly = $false }
    [IO.File]::WriteAllBytes($Path, $Bytes)
    if ((Get-FileSha256 $Path) -ne $Hash) { throw 'file on disk does not match the expected SHA-256 after writing' }
}

# ---------------------------------------------------------------------------
Write-Line '=========================================================='
Write-Line "  $ModTitle" 'Cyan'
Write-Line '  For the Next-Gen Update (Steam, GOG and Epic)'
Write-Line '=========================================================='

$dir = Find-GameDir
if (-not $dir) { Write-Line 'No game folder selected. Nothing was changed.' 'Red'; exit 1 }
Write-Line "Game folder: $dir"

if ($Action -ne 'status' -and (Get-Process -Name 'metro' -ErrorAction SilentlyContinue)) {
    Write-Line 'Metro Last Light Redux is running. Close the game and run this again. Nothing was changed.' 'Red'
    exit 1
}

$backupDir = Join-Path $dir $BackupName
$errors = 0; $warnings = 0
Write-Host ''

foreach ($t in $Targets) {
    $path = Join-Path $dir $t.File
    Write-Line "$($t.File) - $($t.What)"
    try {
        if (-not (Test-Path -LiteralPath $path)) { Write-Line '   missing from the game folder; skipped.' 'Yellow'; $warnings++; continue }
        $h = Get-FileSha256 $path
        $state = 'unknown'
        if ($h -eq $t.Orig) { $state = 'original' } elseif ($h -eq $t.Mod) { $state = 'patched' }

        if ($Action -eq 'status') {
            switch ($state) {
                'original' { Write-Line '   original (not patched)' }
                'patched'  { Write-Line '   patched' 'Green' }
                default    { Write-Line '   unknown version (this mod does not support it)' 'Yellow' }
            }
            continue
        }

        if ($Action -eq 'install') {
            if ($state -eq 'patched') { Write-Line '   already patched.' 'Green'; continue }
            if ($state -ne 'original') {
                Write-Line '   unknown version (maybe a newer game update); left untouched.' 'Yellow'
                $warnings++; continue
            }
            $bytes = [IO.File]::ReadAllBytes($path)
            Set-Bytes $bytes $t.Patches 'New' 'Old'
            if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
            $bk = Join-Path $backupDir $t.File
            if (-not ((Test-Path -LiteralPath $bk) -and ((Get-FileSha256 $bk) -eq $t.Orig))) { Copy-Item -LiteralPath $path -Destination $bk -Force }
            Write-Checked $path $bytes $t.Mod
            Write-Line '   patched and verified.' 'Green'
        }
        else {
            if ($state -eq 'original') { Write-Line '   already original.' 'Green' }
            elseif ($state -eq 'patched') {
                $bytes = [IO.File]::ReadAllBytes($path)
                Set-Bytes $bytes $t.Patches 'Old' 'New'
                Write-Checked $path $bytes $t.Orig
                Write-Line '   restored to the original and verified.' 'Green'
            }
            else {
                Write-Line '   unknown version; left untouched. To restore it: Steam > Properties > Installed Files > Verify integrity.' 'Yellow'
                $warnings++; continue
            }
            $bk = Join-Path $backupDir $t.File
            if (Test-Path -LiteralPath $bk) { Remove-Item -LiteralPath $bk -Force }
        }
    }
    catch [UnauthorizedAccessException] {
        Write-Line '   ERROR: access denied. Right-click the .bat file and choose "Run as administrator".' 'Red'
        Write-Line '   (If it still fails, your antivirus may be blocking the change; see README.txt.)' 'Red'; $errors++
    }
    catch [IO.IOException] {
        Write-Line "   ERROR: $($_.Exception.Message) Close the game (and any tool using its files) and try again." 'Red'; $errors++
    }
    catch {
        Write-Line "   ERROR: $($_.Exception.Message). The file was not changed." 'Red'; $errors++
    }
}

if ($Action -eq 'uninstall' -and (Test-Path -LiteralPath $backupDir) -and -not (Get-ChildItem -LiteralPath $backupDir -Force)) {
    Remove-Item -LiteralPath $backupDir -Force
}

Write-Host ''
if ($errors -gt 0) { Write-Line "Finished with $errors error(s)." 'Red'; exit 1 }
if ($Action -eq 'install') {
    if ($warnings -eq 0) { Write-Line 'Done. Start the game normally: no ad tile and no telemetry.' 'Green' }
    elseif ($warnings -lt $Targets.Count) { Write-Line "Partly applied: $warnings file(s) skipped; see the messages above." 'Yellow' }
    else { Write-Line 'Nothing was patched; see the messages above.' 'Yellow' }
    if (Test-Path -LiteralPath $backupDir) { Write-Line "Original files backed up in: $backupDir" }
}
elseif ($Action -eq 'uninstall') {
    if ($warnings -eq 0) { Write-Line 'Done. The game files are back to the originals.' 'Green' }
    else { Write-Line "$warnings file(s) could not be restored; see the messages above." 'Yellow' }
}
exit 0
