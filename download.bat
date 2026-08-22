@echo off
setlocal
set "PATCH_VERSION=v0.0.3"

rem ANSI colors (Windows 10+): get the ESC character, then define color codes
for /F "delims=" %%a in ('forfiles /p "%~dp0." /m "%~nx0" /c "cmd /c echo 0x1B"') do set "ESC=%%a"
set "CYAN=%ESC%[96m"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "RESET=%ESC%[0m"

choice /C YN /M "Do you have Rec Room in your Steam library? "
if errorlevel 2 goto :nomirror

:steam
set "STEAM_USERNAME="
set /p STEAM_USERNAME=Enter your Steam username:
if "%STEAM_USERNAME%"=="" (
    echo %RED%No username entered - stopping.%RESET%
    exit /b 1
)

echo %CYAN%=== Installing DepotDownloader ===%RESET%
curl -s -f -L -o DepotDownloader.zip https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_3.4.0/DepotDownloader-windows-x64.zip || goto :error
if not exist "DepotDownloader" mkdir "DepotDownloader"
tar -xf DepotDownloader.zip -C DepotDownloader || goto :error
del DepotDownloader.zip

echo %CYAN%=== Downloading depot via DepotDownloader (will prompt for Steam password) ===%RESET%
DepotDownloader\DepotDownloader.exe -remember-password -app 471710 -depot 471711 -manifest 1151455856673601091 -dir . -username "%STEAM_USERNAME%" || goto :error
goto :patch

:nomirror
echo %RED%The mirror download is unavailable right now - Rec Room in your Steam library%RESET%
echo %RED%is required. Answer Y above once the mirror is back.%RESET%
pause
exit /b 1

rem Mirror path below is offline for now - nothing jumps to :bucket until it is back.
:bucket
set "CLIENT_MD5=4c4a94624eba99028bb36445ccb03253"
if not exist client.zip goto :download
echo %CYAN%=== Checking existing client.zip ===%RESET%
set "LOCAL_MD5="
for /f "skip=1 delims=" %%h in ('certutil -hashfile client.zip MD5') do if not defined LOCAL_MD5 set "LOCAL_MD5=%%h"
if /i "%LOCAL_MD5%"=="%CLIENT_MD5%" (
    echo %GREEN%client.zip already matches expected hash - skipping download.%RESET%
    goto :extract
)
echo %RED%client.zip does not match expected hash - redownloading.%RESET%

:download
echo %CYAN%=== Downloading game client from mirror ===%RESET%
curl -f -L -o client.zip https://s3.g.megas4.com/2koayuyiwxv4groxzwdbbxg43cwustavrkvfb/recflare/client.zip || goto :error

:extract
echo %CYAN%=== Extracting game client ===%RESET%
tar -xf client.zip -C . || goto :error

:patch
echo %CYAN%=== Writing steam_appid.txt ===%RESET%
>steam_appid.txt echo 480

echo %CYAN%=== Downloading Rec Room 2025 patch ===%RESET%
curl -s -f -L -o 2025Patch.zip https://github.com/djdevin/Rec-Room-2025-Patch/releases/download/%PATCH_VERSION%/2025Patch-%PATCH_VERSION%-x64.zip || goto :error
tar -xf 2025Patch.zip -C . || goto :error
del 2025Patch.zip

echo %CYAN%=== Pointing 2025patch.ini at RecFlare ===%RESET%
powershell -NoProfile -Command "$p='2025patch.ini'; $h=@{ApiHost='ns.recflare.net';PhotonHost='photon.recflare.net'}; $t=@(if (Test-Path $p) { Get-Content $p } else { '[config]' }); foreach ($k in $h.Keys) { $r='^\s*'+$k+'\s*='; if ($t -match $r) { $t = $t -replace ($r+'.*'), ($k+'='+$h[$k]) } else { $t += ($k+'='+$h[$k]) } }; Set-Content -Path $p -Value $t -Encoding ASCII" || goto :error

echo %GREEN%=== Done ===%RESET%
pause
exit /b 0

:error
echo.
echo %RED%*** FAILED with error code %errorlevel% - stopping. ***%RESET%
pause
exit /b %errorlevel%
