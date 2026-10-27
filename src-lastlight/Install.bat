@echo off
title Metro Last Light Redux - No Ads and Telemetry - Install
rem Double-click: the game folder is found automatically. You can also drag the game folder onto this file.
if not exist "%~dp0NoAdsTelemetry.ps1" goto :not_extracted
powershell.exe -ExecutionPolicy Bypass -File "%~dp0NoAdsTelemetry.ps1" -Action install %*
echo.
pause
exit /b
:not_extracted
echo NoAdsTelemetry.ps1 was not found next to this file.
echo Extract the whole zip first (right-click the zip ^> Extract All...),
echo then run Install.bat from the extracted folder.
echo.
pause
exit /b 1
