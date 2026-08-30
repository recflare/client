; RecFlare installer - GUI equivalent of download.bat.
; Build with Inno Setup 6.1+ (https://jrsoftware.org/isinfo.php):
;   iscc RecFlareSetup.iss
; Output: Output\RecFlareSetup.exe

[Setup]
AppId={{8E1D2A7B-6C43-4F0A-9B7E-3D5F80C21A96}
AppName=RecFlare
AppVersion=2025.1
AppPublisher=RecFlare project
AppSupportURL=https://github.com/djdevin/recflare
DefaultDirName={sd}\Games\RecFlare
PrivilegesRequired=lowest
; tar.exe ships with Windows 10 1803+; the downloads and extraction depend on it
MinVersion=10.0.17134
WizardStyle=modern
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\icon.ico
DisableProgramGroupPage=yes
OutputBaseFilename=RecFlareSetup
SolidCompression=yes
UninstallDisplayName=RecFlare

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "RecRoomScreen.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "RecRoomVR.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\RecFlare (Desktop mode)"; Filename: "{app}\recroom.exe"; Parameters: "+forcemode:screen"; WorkingDir: "{app}"; IconFilename: "{app}\icon.ico"
Name: "{autoprograms}\RecFlare (VR)"; Filename: "{app}\recroom.exe"; Parameters: "+forcemode:vr"; WorkingDir: "{app}"; IconFilename: "{app}\icon.ico"
Name: "{autodesktop}\RecFlare (Desktop mode)"; Filename: "{app}\recroom.exe"; Parameters: "+forcemode:screen"; WorkingDir: "{app}"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon
Name: "{autodesktop}\RecFlare (VR)"; Filename: "{app}\recroom.exe"; Parameters: "+forcemode:vr"; WorkingDir: "{app}"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[UninstallDelete]
; The game files are downloaded, not installed, so Inno does not track them;
; remove the whole folder on uninstall.
Type: filesandordirs; Name: "{app}"

[Code]
const
  PatchVersion = 'v0.0.5';
  DepotManifest = '1151455856673601091';
  ClientMD5 = '6820e89bff41906ded7f5c066027f1d6';
  ClientURL = 'https://s3.g.megas4.com/2koayuyiwxv4groxzwdbbxg43cwustavrkvfb/recflare/2025/client.zip';
  DepotDownloaderURL = 'https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_3.4.0/DepotDownloader-windows-x64.zip';
  PatchURL = 'https://github.com/recflare/patch-2025/releases/download/' + PatchVersion + '/2025Patch-' + PatchVersion + '-x64.zip';
  { Points the client at the RecFlare server; to use your own instance, fork and
    change these, then rebuild the installer (see README "Custom server"). }
  ApiHost = 'ns.recflare.net';
  PhotonHost = 'photon.recflare.net';

var
  SourcePage: TInputOptionWizardPage;
  SteamPage: TInputQueryWizardPage;
  DownloadPage: TDownloadWizardPage;
  ReuseLocalClientZip: Boolean;

function UsingSteam: Boolean;
begin
  Result := SourcePage.Values[0];
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if Progress = ProgressMax then
    Log(Format('Downloaded %s', [FileName]));
  Result := True;
end;

procedure InitializeWizard;
begin
  SourcePage := CreateInputOptionPage(wpSelectDir,
    'Game client source', 'Where should the game files come from?',
    'Setup needs a copy of the Rec Room game client. Pick the option that applies to you, then click Next.',
    True, False);
  SourcePage.Add('I have Rec Room in my Steam library - download it from Steam');
  SourcePage.Add('I do not have it on Steam - download from the community mirror');
  SourcePage.SelectedValueIndex := 0;

  SteamPage := CreateInputQueryPage(SourcePage.ID,
    'Steam sign-in', 'How should the Steam download sign in?',
    'Enter your Steam username, or leave it blank to sign in by scanning a QR code with the Steam mobile app. ' +
    'A separate Steam window will open during installation to finish signing in; ' +
    'this installer never sees your password.');
  SteamPage.Add('Steam username (optional):', False);

  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing),
    SetupMessage(msgPreparingDesc), @OnDownloadProgress);
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = SteamPage.ID) and not UsingSteam;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpReady then begin
    DownloadPage.Clear;
    ReuseLocalClientZip := False;
    if UsingSteam then
      DownloadPage.Add(DepotDownloaderURL, 'DepotDownloader.zip', '')
    else begin
      { A client.zip left behind by download.bat (or a previous run) is reused
        when it matches the expected hash, like the .bat does. }
      if FileExists(ExpandConstant('{app}\client.zip')) and
         SameText(GetMD5OfFile(ExpandConstant('{app}\client.zip')), ClientMD5) then
        ReuseLocalClientZip := True
      else
        DownloadPage.Add(ClientURL, 'client.zip', '');
    end;
    DownloadPage.Add(PatchURL, '2025Patch.zip', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
        if not UsingSteam and not ReuseLocalClientZip and
           not SameText(GetMD5OfFile(ExpandConstant('{tmp}\client.zip')), ClientMD5) then begin
          SuppressibleMsgBox('The downloaded game client did not match the expected checksum. ' +
            'Please run Setup again.', mbCriticalError, MB_OK, IDOK);
          Result := False;
        end;
      except
        if DownloadPage.AbortedByUser then
          Log('Download aborted by user.')
        else
          SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;

procedure SetPreparingStatus(const Msg: String);
begin
  WizardForm.PreparingLabel.Visible := True;
  WizardForm.PreparingLabel.Caption := Msg;
  WizardForm.Refresh;
end;

function ExtractZip(const ZipPath, DestDir: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := ForceDirectories(DestDir) and
    Exec(ExpandConstant('{sys}\tar.exe'), Format('-xf "%s" -C "%s"', [ZipPath, DestDir]),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function RunDepotDownloader(var ErrorMsg: String): Boolean;
var
  Args: String;
  ResultCode: Integer;
begin
  Result := False;
  if not ExtractZip(ExpandConstant('{tmp}\DepotDownloader.zip'), ExpandConstant('{tmp}\DepotDownloader')) then begin
    ErrorMsg := 'Could not extract DepotDownloader.';
    Exit;
  end;
  Args := '-app 471710 -depot 471711 -manifest ' + DepotManifest + ' -remember-password' +
    ' -dir "' + ExpandConstant('{app}') + '"';
  if Trim(SteamPage.Values[0]) <> '' then
    Args := Args + ' -username "' + Trim(SteamPage.Values[0]) + '"'
  else
    Args := Args + ' -qr';
  SetPreparingStatus('Downloading the game from Steam - follow the sign-in steps in the window that just opened...');
  if not Exec(ExpandConstant('{tmp}\DepotDownloader\DepotDownloader.exe'), Args,
      ExpandConstant('{tmp}\DepotDownloader'), SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode)
     or (ResultCode <> 0) then begin
    ErrorMsg := 'The Steam download did not complete (exit code ' + IntToStr(ResultCode) + '). ' +
      'Check that your sign-in succeeded and that Rec Room is in your Steam library, then run Setup again.';
    Exit;
  end;
  Result := True;
end;

{ Sets Key=Value in the ini shipped by the patch, replacing an existing line
  for that key or appending one, so other settings in the file are kept. }
procedure SetIniKey(var Lines: TArrayOfString; const Key, Value: String);
var
  I: Integer;
  L: String;
begin
  for I := 0 to GetArrayLength(Lines) - 1 do begin
    L := Trim(Lines[I]);
    if (Pos('=', L) > 0) and SameText(Trim(Copy(L, 1, Pos('=', L) - 1)), Key) then begin
      Lines[I] := Key + '=' + Value;
      Exit;
    end;
  end;
  SetArrayLength(Lines, GetArrayLength(Lines) + 1);
  Lines[GetArrayLength(Lines) - 1] := Key + '=' + Value;
end;

function WritePatchIni(const IniPath: String): Boolean;
var
  Lines: TArrayOfString;
begin
  if not FileExists(IniPath) or not LoadStringsFromFile(IniPath, Lines) then begin
    SetArrayLength(Lines, 1);
    Lines[0] := '[config]';
  end;
  SetIniKey(Lines, 'ApiHost', ApiHost);
  SetIniKey(Lines, 'PhotonHost', PhotonHost);
  Result := SaveStringsToFile(IniPath, Lines, False);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ClientZip: String;
begin
  Result := '';
  if not ForceDirectories(ExpandConstant('{app}')) then begin
    Result := 'Could not create the installation folder.';
    Exit;
  end;

  if UsingSteam then begin
    if not RunDepotDownloader(Result) then
      Exit;
  end else begin
    if ReuseLocalClientZip then
      ClientZip := ExpandConstant('{app}\client.zip')
    else
      ClientZip := ExpandConstant('{tmp}\client.zip');
    SetPreparingStatus('Extracting the game client (this can take a few minutes)...');
    if not ExtractZip(ClientZip, ExpandConstant('{app}')) then begin
      Result := 'Could not extract the game client archive.';
      Exit;
    end;
  end;

  if not SaveStringToFile(ExpandConstant('{app}\steam_appid.txt'), '480', False) then begin
    Result := 'Could not write steam_appid.txt.';
    Exit;
  end;

  SetPreparingStatus('Installing the Rec Room 2025 patch...');
  if not ExtractZip(ExpandConstant('{tmp}\2025Patch.zip'), ExpandConstant('{app}')) then begin
    Result := 'Could not extract the Rec Room 2025 patch.';
    Exit;
  end;

  if not WritePatchIni(ExpandConstant('{app}\2025patch.ini')) then begin
    Result := 'Could not write 2025patch.ini.';
    Exit;
  end;
end;
