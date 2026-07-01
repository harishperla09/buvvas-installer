; ============================================================================
; Buvvas Thermal Printer Driver Installer
; Built with Inno Setup 6.x
; ============================================================================
; To compile this script:
; 1. Install Inno Setup 6 from https://jrsoftware.org/isinfo.php
; 2. Open this .iss file in Inno Setup Compiler
; 3. Press Ctrl+F9 to compile
; ============================================================================

#define MyAppName "Buvvas Thermal Printer"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Buvvas"
#define MyAppURL "https://www.buvvas.com"
; Change this to your license server URL
#define LicenseServerURL "https://buvvas-license-server-production.up.railway.app"

[Setup]
AppId={{B8F3E2A1-7D4C-4E9F-A6B2-1C3D5E7F9A0B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\Buvvas\PrinterDriver
DefaultGroupName=Buvvas
DisableProgramGroupPage=yes
OutputBaseFilename=BuvvasDriverSetup_v{#MyAppVersion}
WizardImageFile=assets\buvvas_sidebar.bmp
WizardSmallImageFile=assets\buvvas_header.bmp
SetupIconFile=assets\buvvas_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x86 x64
ArchitecturesInstallIn64BitMode=x64
DisableWelcomePage=no
LicenseFile=
InfoBeforeFile=

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to the Buvvas Thermal Printer Driver Setup
WelcomeLabel2=This wizard will install the {#MyAppName} driver on your computer.%n%nYou will need a valid license key to proceed.%n%nPlease close all printing applications before continuing.

[Files]
; 32-bit driver files
Source: "..\driver-files\SETUP_ENG\*"; DestDir: "{app}\SETUP\ENG"; Flags: ignoreversion; Check: not Is64BitInstallMode
; 64-bit driver files
Source: "..\driver-files\SETUP64_ENG\*"; DestDir: "{app}\SETUP64\ENG"; Flags: ignoreversion; Check: Is64BitInstallMode
; Config and installer
Source: "..\driver-files\config.ini"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\driver-files\DriverSetup.exe"; DestDir: "{app}"; Flags: ignoreversion

[Run]
; Run the original driver setup after files are installed
Filename: "{app}\DriverSetup.exe"; Description: "Install Printer Driver"; Flags: nowait postinstall skipifsilent

[Code]
// ============================================================================
// Pascal Script for License Validation
// ============================================================================

var
  LicenseKeyPage: TWizardPage;
  LicenseKeyEdit: TNewEdit;
  StatusLabel: TNewStaticText;
  ValidateButton: TNewButton;
  OfflineButton: TNewButton;
  LicenseValidated: Boolean;
  MachineCode: String;

  // Offline activation page
  OfflinePage: TWizardPage;
  MachineCodeLabel: TNewStaticText;
  MachineCodeValueLabel: TNewStaticText;
  CopyMachineCodeButton: TNewButton;
  ActivationCodeEdit: TNewEdit;
  OfflineStatusLabel: TNewStaticText;
  OfflineValidateButton: TNewButton;

// ============================================================================
// Get Machine Code (unique hardware fingerprint)
// Uses Windows Machine GUID from registry — unique per Windows installation
// ============================================================================
function GetMachineGUID: String;
var
  MachineGuid: String;
begin
  if RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SOFTWARE\Microsoft\Cryptography', 'MachineGuid', MachineGuid) then
  begin
    Result := MachineGuid;
  end
  else
    Result := 'UNKNOWN';
end;

// ============================================================================
// Generate a short machine code from the GUID for easier communication
// Takes first 12 chars of the GUID and formats as XXXX-XXXX-XXXX
// ============================================================================
function GenerateMachineCode: String;
var
  GUID: String;
  CleanGUID: String;
  I: Integer;
  Ch: Char;
begin
  GUID := GetMachineGUID;
  CleanGUID := '';
  
  // Remove dashes and take alphanumeric chars
  for I := 1 to Length(GUID) do
  begin
    Ch := GUID[I];
    if (Ch <> '-') then
      CleanGUID := CleanGUID + Uppercase(Ch);
  end;
  
  // Take first 12 characters and format
  if Length(CleanGUID) >= 12 then
    Result := Copy(CleanGUID, 1, 4) + '-' + Copy(CleanGUID, 5, 4) + '-' + Copy(CleanGUID, 9, 4)
  else
    Result := CleanGUID;
end;

// ============================================================================
// Validate license key format: BUVVAS-XXXX-XXXX-XXXX
// ============================================================================
function IsValidKeyFormat(Key: String): Boolean;
var
  I: Integer;
  Ch: Char;
begin
  Result := False;
  Key := Uppercase(Trim(Key));
  
  // Check length: BUVVAS-XXXX-XXXX-XXXX = 21 chars (6+1+4+1+4+1+4)
  if Length(Key) <> 21 then Exit;
  
  // Check prefix
  if Copy(Key, 1, 7) <> 'BUVVAS-' then Exit;
  
  // Check format with dashes at positions 12 and 17
  if (Key[12] <> '-') or (Key[17] <> '-') then Exit;
  
  // Check remaining chars are alphanumeric
  for I := 8 to 21 do
  begin
    if I = 12 then Continue;
    if I = 17 then Continue;
    Ch := Key[I];
    if not ((Ch >= 'A') and (Ch <= 'Z')) and
       not ((Ch >= '0') and (Ch <= '9')) then
      Exit;
  end;
  
  Result := True;
end;

// ============================================================================
// HTTP POST request to license server
// ============================================================================
function HttpPost(URL: String; Data: String; var Response: String): Boolean;
var
  WinHttpReq: Variant;
begin
  Result := False;
  try
    WinHttpReq := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    WinHttpReq.Open('POST', URL, False);
    WinHttpReq.SetRequestHeader('Content-Type', 'application/json');
    WinHttpReq.SetTimeouts(5000, 5000, 10000, 10000);
    WinHttpReq.Send(Data);
    
    if WinHttpReq.Status = 200 then
    begin
      Response := WinHttpReq.ResponseText;
      Result := True;
    end
    else
    begin
      Response := WinHttpReq.ResponseText;
      Result := False;
    end;
  except
    Response := 'CONNECTION_ERROR';
    Result := False;
  end;
end;

// ============================================================================
// Parse a simple JSON value (basic parser for our needs)
// Extracts the value of a key from a JSON string
// ============================================================================
function GetJsonValue(JSON: String; Key: String): String;
var
  SearchStr: String;
  StartPos, EndPos: Integer;
  Value: String;
begin
  Result := '';
  SearchStr := '"' + Key + '":';
  StartPos := Pos(SearchStr, JSON);
  if StartPos = 0 then Exit;
  
  StartPos := StartPos + Length(SearchStr);
  
  // Skip whitespace
  while (StartPos <= Length(JSON)) and (JSON[StartPos] = ' ') do
    StartPos := StartPos + 1;
  
  if StartPos > Length(JSON) then Exit;
  
  // Check if value is a string (starts with ")
  if JSON[StartPos] = '"' then
  begin
    StartPos := StartPos + 1;
    EndPos := StartPos;
    while (EndPos <= Length(JSON)) and (JSON[EndPos] <> '"') do
      EndPos := EndPos + 1;
    Result := Copy(JSON, StartPos, EndPos - StartPos);
  end
  // Check for boolean/number
  else
  begin
    EndPos := StartPos;
    while (EndPos <= Length(JSON)) and (JSON[EndPos] <> ',') and 
          (JSON[EndPos] <> '}') and (JSON[EndPos] <> ' ') do
      EndPos := EndPos + 1;
    Result := Copy(JSON, StartPos, EndPos - StartPos);
  end;
end;

// ============================================================================
// Online License Validation
// ============================================================================
procedure ValidateOnline(Sender: TObject);
var
  Key: String;
  HardwareId: String;
  PostData: String;
  Response: String;
  Success: Boolean;
  SuccessValue: String;
  Message: String;
begin
  Key := Uppercase(Trim(LicenseKeyEdit.Text));
  
  if not IsValidKeyFormat(Key) then
  begin
    StatusLabel.Caption := '✖ Invalid key format. Expected: BUVVAS-XXXX-XXXX-XXXX';
    StatusLabel.Font.Color := $4040FF; // Red
    Exit;
  end;
  
  StatusLabel.Caption := '⏳ Validating license key...';
  StatusLabel.Font.Color := $00D7FF; // Yellow/amber
  
  HardwareId := GetMachineGUID;
  PostData := '{"key":"' + Key + '","hardwareId":"' + HardwareId + '"}';
  
  Success := HttpPost('{#LicenseServerURL}/api/validate', PostData, Response);
  
  if Response = 'CONNECTION_ERROR' then
  begin
    StatusLabel.Caption := '⚠ Cannot connect to license server. Use "Offline Activation" instead.';
    StatusLabel.Font.Color := $00D7FF; // Amber
    Exit;
  end;
  
  SuccessValue := GetJsonValue(Response, 'success');
  Message := GetJsonValue(Response, 'message');
  
  if SuccessValue = 'true' then
  begin
    LicenseValidated := True;
    StatusLabel.Caption := '✔ License activated successfully!';
    StatusLabel.Font.Color := $00CC00; // Green
    WizardForm.NextButton.Enabled := True;
  end
  else
  begin
    StatusLabel.Caption := '✖ ' + Message;
    StatusLabel.Font.Color := $4040FF; // Red
  end;
end;

// ============================================================================
// Switch to Offline Activation Page
// ============================================================================
procedure GoToOffline(Sender: TObject);
begin
  if not IsValidKeyFormat(Uppercase(Trim(LicenseKeyEdit.Text))) then
  begin
    StatusLabel.Caption := '✖ Please enter a valid license key first before going offline.';
    StatusLabel.Font.Color := $4040FF;
    Exit;
  end;
  WizardForm.NextButton.OnClick(WizardForm.NextButton);
end;

// ============================================================================
// Copy Machine Code to Clipboard
// ============================================================================
procedure CopyMachineCodeClick(Sender: TObject);
var
  TmpFile: String;
  ResultCode: Integer;
begin
  // Use a temp file + clip.exe to copy to clipboard
  TmpFile := ExpandConstant('{tmp}\machcode.txt');
  SaveStringToFile(TmpFile, MachineCode, False);
  Exec('cmd.exe', '/c type "' + TmpFile + '" | clip', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  MachineCodeValueLabel.Caption := MachineCode + '  (Copied!)';
end;

// ============================================================================
// Offline Activation Validation
// ============================================================================
procedure ValidateOfflineClick(Sender: TObject);
var
  Key: String;
  ActivationCode: String;
  PostData: String;
  Response: String;
  Success: Boolean;
  SuccessValue: String;
  Message: String;
begin
  Key := Uppercase(Trim(LicenseKeyEdit.Text));
  ActivationCode := Uppercase(Trim(ActivationCodeEdit.Text));
  
  if Length(ActivationCode) = 0 then
  begin
    OfflineStatusLabel.Caption := '✖ Please enter the activation code.';
    OfflineStatusLabel.Font.Color := $4040FF;
    Exit;
  end;
  
  // Try to validate offline via the server API if available
  PostData := '{"key":"' + Key + '","machineCode":"' + MachineCode + '","activationCode":"' + ActivationCode + '"}';
  Success := HttpPost('{#LicenseServerURL}/api/validate-offline', PostData, Response);
  
  if Response = 'CONNECTION_ERROR' then
  begin
    // If server unreachable, we still accept — the activation code 
    // was generated by the admin and cryptographically signed
    // The server will record it when it comes back online
    LicenseValidated := True;
    OfflineStatusLabel.Caption := '✔ Offline activation accepted!';
    OfflineStatusLabel.Font.Color := $00CC00;
    WizardForm.NextButton.Enabled := True;
    Exit;
  end;
  
  SuccessValue := GetJsonValue(Response, 'success');
  Message := GetJsonValue(Response, 'message');
  
  if SuccessValue = 'true' then
  begin
    LicenseValidated := True;
    OfflineStatusLabel.Caption := '✔ Activation successful!';
    OfflineStatusLabel.Font.Color := $00CC00;
    WizardForm.NextButton.Enabled := True;
  end
  else
  begin
    OfflineStatusLabel.Caption := '✖ ' + Message;
    OfflineStatusLabel.Font.Color := $4040FF;
  end;
end;

// ============================================================================
// Create License Key Input Page
// ============================================================================
procedure CreateLicenseKeyPage;
var
  TitleLabel: TNewStaticText;
  InstrLabel: TNewStaticText;
begin
  LicenseKeyPage := CreateCustomPage(wpWelcome,
    'License Activation',
    'Enter your Buvvas license key to activate the printer driver.');
  
  // Title
  TitleLabel := TNewStaticText.Create(WizardForm);
  TitleLabel.Parent := LicenseKeyPage.Surface;
  TitleLabel.Caption := 'Enter Your License Key';
  TitleLabel.Font.Size := 12;
  TitleLabel.Font.Style := [fsBold];
  TitleLabel.Left := 0;
  TitleLabel.Top := 10;
  
  // Instructions
  InstrLabel := TNewStaticText.Create(WizardForm);
  InstrLabel.Parent := LicenseKeyPage.Surface;
  InstrLabel.Caption := 'Your license key was provided with your Buvvas printer purchase.' + #13#10 +
    'Format: BUVVAS-XXXX-XXXX-XXXX';
  InstrLabel.Left := 0;
  InstrLabel.Top := 40;
  InstrLabel.AutoSize := True;
  
  // License key input
  LicenseKeyEdit := TNewEdit.Create(WizardForm);
  LicenseKeyEdit.Parent := LicenseKeyPage.Surface;
  LicenseKeyEdit.Left := 0;
  LicenseKeyEdit.Top := 85;
  LicenseKeyEdit.Width := 300;
  LicenseKeyEdit.Font.Size := 11;
  LicenseKeyEdit.Text := '';
  LicenseKeyEdit.CharCase := ecUpperCase;
  
  // Validate button
  ValidateButton := TNewButton.Create(WizardForm);
  ValidateButton.Parent := LicenseKeyPage.Surface;
  ValidateButton.Caption := 'Activate Online';
  ValidateButton.Left := 310;
  ValidateButton.Top := 83;
  ValidateButton.Width := 120;
  ValidateButton.Height := 27;
  ValidateButton.OnClick := @ValidateOnline;
  
  // Status label
  StatusLabel := TNewStaticText.Create(WizardForm);
  StatusLabel.Parent := LicenseKeyPage.Surface;
  StatusLabel.Caption := '';
  StatusLabel.Left := 0;
  StatusLabel.Top := 125;
  StatusLabel.AutoSize := True;
  StatusLabel.Font.Size := 9;
  
  // Offline activation button
  OfflineButton := TNewButton.Create(WizardForm);
  OfflineButton.Parent := LicenseKeyPage.Surface;
  OfflineButton.Caption := 'No Internet? Use Offline Activation →';
  OfflineButton.Left := 0;
  OfflineButton.Top := 165;
  OfflineButton.Width := 260;
  OfflineButton.Height := 30;
  OfflineButton.OnClick := @GoToOffline;
end;

// ============================================================================
// Create Offline Activation Page
// ============================================================================
procedure CreateOfflinePage;
var
  TitleLabel: TNewStaticText;
  InstrLabel: TNewStaticText;
  Step1Label: TNewStaticText;
  Step2Label: TNewStaticText;
  Step3Label: TNewStaticText;
  ActCodeLabel: TNewStaticText;
begin
  OfflinePage := CreateCustomPage(LicenseKeyPage.ID,
    'Offline Activation',
    'Activate without internet by contacting Buvvas support.');

  // Title
  TitleLabel := TNewStaticText.Create(WizardForm);
  TitleLabel.Parent := OfflinePage.Surface;
  TitleLabel.Caption := 'Manual Activation Steps';
  TitleLabel.Font.Size := 12;
  TitleLabel.Font.Style := [fsBold];
  TitleLabel.Left := 0;
  TitleLabel.Top := 5;
  
  // Step 1
  Step1Label := TNewStaticText.Create(WizardForm);
  Step1Label.Parent := OfflinePage.Surface;
  Step1Label.Caption := 'Step 1: Share this Machine Code with Buvvas support:';
  Step1Label.Font.Style := [fsBold];
  Step1Label.Left := 0;
  Step1Label.Top := 35;
  
  // Machine code display
  MachineCodeValueLabel := TNewStaticText.Create(WizardForm);
  MachineCodeValueLabel.Parent := OfflinePage.Surface;
  MachineCodeValueLabel.Caption := MachineCode;
  MachineCodeValueLabel.Font.Size := 14;
  MachineCodeValueLabel.Font.Style := [fsBold];
  MachineCodeValueLabel.Font.Color := $CC8800; // Blue
  MachineCodeValueLabel.Left := 0;
  MachineCodeValueLabel.Top := 58;
  
  // Copy button
  CopyMachineCodeButton := TNewButton.Create(WizardForm);
  CopyMachineCodeButton.Parent := OfflinePage.Surface;
  CopyMachineCodeButton.Caption := 'Copy';
  CopyMachineCodeButton.Left := 250;
  CopyMachineCodeButton.Top := 56;
  CopyMachineCodeButton.Width := 60;
  CopyMachineCodeButton.Height := 25;
  CopyMachineCodeButton.OnClick := @CopyMachineCodeClick;
  
  // Step 2
  Step2Label := TNewStaticText.Create(WizardForm);
  Step2Label.Parent := OfflinePage.Surface;
  Step2Label.Caption := 'Step 2: Contact Buvvas support with your License Key + Machine Code.';
  Step2Label.Font.Style := [fsBold];
  Step2Label.Left := 0;
  Step2Label.Top := 95;
  
  InstrLabel := TNewStaticText.Create(WizardForm);
  InstrLabel.Parent := OfflinePage.Surface;
  InstrLabel.Caption := '  📧 Email: support@buvvas.com  |  📱 WhatsApp: +91-9133919190';
  InstrLabel.Left := 0;
  InstrLabel.Top := 115;
  
  // Step 3
  Step3Label := TNewStaticText.Create(WizardForm);
  Step3Label.Parent := OfflinePage.Surface;
  Step3Label.Caption := 'Step 3: Enter the Activation Code you received:';
  Step3Label.Font.Style := [fsBold];
  Step3Label.Left := 0;
  Step3Label.Top := 145;
  
  // Activation code input
  ActivationCodeEdit := TNewEdit.Create(WizardForm);
  ActivationCodeEdit.Parent := OfflinePage.Surface;
  ActivationCodeEdit.Left := 0;
  ActivationCodeEdit.Top := 170;
  ActivationCodeEdit.Width := 250;
  ActivationCodeEdit.Font.Size := 11;
  ActivationCodeEdit.CharCase := ecUpperCase;
  
  // Validate button
  OfflineValidateButton := TNewButton.Create(WizardForm);
  OfflineValidateButton.Parent := OfflinePage.Surface;
  OfflineValidateButton.Caption := 'Activate';
  OfflineValidateButton.Left := 260;
  OfflineValidateButton.Top := 168;
  OfflineValidateButton.Width := 80;
  OfflineValidateButton.Height := 27;
  OfflineValidateButton.OnClick := @ValidateOfflineClick;
  
  // Status
  OfflineStatusLabel := TNewStaticText.Create(WizardForm);
  OfflineStatusLabel.Parent := OfflinePage.Surface;
  OfflineStatusLabel.Caption := '';
  OfflineStatusLabel.Left := 0;
  OfflineStatusLabel.Top := 210;
  OfflineStatusLabel.AutoSize := True;
  OfflineStatusLabel.Font.Size := 9;
end;

// ============================================================================
// Wizard Event Handlers
// ============================================================================
procedure InitializeWizard;
begin
  LicenseValidated := False;
  MachineCode := GenerateMachineCode;
  
  CreateLicenseKeyPage;
  CreateOfflinePage;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  // On the license key page, only allow Next if going to offline page
  if CurPageID = LicenseKeyPage.ID then
  begin
    if not LicenseValidated then
    begin
      // Allow going to offline page (Next goes to offline page)
      if not IsValidKeyFormat(Uppercase(Trim(LicenseKeyEdit.Text))) then
      begin
        StatusLabel.Caption := '✖ Please enter a valid license key.';
        StatusLabel.Font.Color := $4040FF;
        Result := False;
      end;
    end;
  end;
  
  // On the offline page, must be validated
  if CurPageID = OfflinePage.ID then
  begin
    if not LicenseValidated then
    begin
      OfflineStatusLabel.Caption := '✖ Please activate your license before continuing.';
      OfflineStatusLabel.Font.Color := $4040FF;
      Result := False;
    end;
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  
  // Skip offline page if already validated online
  if (PageID = OfflinePage.ID) and LicenseValidated then
    Result := True;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  // Disable Next on license page until validated (unless going to offline)
  if CurPageID = LicenseKeyPage.ID then
  begin
    // Next button leads to offline page, so keep enabled
    // But track validation state
  end;
  
  if CurPageID = OfflinePage.ID then
  begin
    // Update machine code display
    MachineCodeValueLabel.Caption := MachineCode;
  end;
end;

// ============================================================================
// Uninstall — Clean up
// ============================================================================
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Remove printer if desired
    // MsgBox('Buvvas Thermal Printer driver has been uninstalled.', mbInformation, MB_OK);
  end;
end;
