@echo off
setlocal

rem ANSI colors (Windows 10+): get the ESC character, then define color codes
for /F "delims=" %%a in ('forfiles /p "%~dp0." /m "%~nx0" /c "cmd /c echo 0x1B"') do set "ESC=%%a"
set "CYAN=%ESC%[96m"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "RESET=%ESC%[0m"

choice /C YN /M "Do you have Rec Room in your Steam library? "
if errorlevel 2 goto :bucket

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
DepotDownloader\DepotDownloader.exe -remember-password -app 471710 -depot 471711 -manifest 6426603215211043630 -dir . -username "%STEAM_USERNAME%" || goto :error
goto :patch

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

echo %CYAN%=== Downloading BepInEx and extracting to this directory ===%RESET%
curl -s -f -L -o BepInEx.zip https://github.com/BepInEx/BepInEx/releases/download/v6.0.0-pre.2/BepInEx-Unity.IL2CPP-win-x64-6.0.0-pre.2.zip || goto :error
tar -xf BepInEx.zip -C . || goto :error
del BepInEx.zip

echo %CYAN%=== Downloading RecNetPlugin.dll into BepInEx\plugins ===%RESET%
if not exist "BepInEx\plugins" mkdir "BepInEx\plugins"
curl -s -f -L -o "BepInEx\plugins\RecNetPlugin.dll" https://github.com/djdevin/recnet-plugin/releases/download/20230414.2/RecNetPlugin.dll || goto :error

echo %GREEN%=== Done ===%RESET%
pause
exit /b 0

:error
echo.
echo %RED%*** FAILED with error code %errorlevel% - stopping. ***%RESET%
pause
exit /b %errorlevel%
