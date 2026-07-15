#define MyAppName "ALICE PaperPal"
#define MyAppPublisher "ALICE"
#define MyAppURL "https://github.com/jonah791/alice-paperpal"
#define MyAppExeName "paperpal.exe"

[Setup]
AppId={{B7A3D1C2-8E5F-4A9B-9C6D-2E3F1A0B4C7D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\build\installer
OutputBaseFilename=ALICE-PaperPal-{#MyAppVersion}-Setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
ChangesAssociations=yes
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:ProgramOnTheWeb,{#MyAppName}}"; Filename: "{#MyAppURL}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
; .pdf association
Root: "HKCR"; Subkey: ".pdf\OpenWithProgids"; ValueType: string; ValueName: "PaperPal.PDF"; ValueData: ""; Flags: uninsdeletevalue
Root: "HKCR"; Subkey: "PaperPal.PDF"; ValueType: string; ValueName: ""; ValueData: "PaperPal Document"; Flags: uninsdeletekey
Root: "HKCR"; Subkey: "PaperPal.PDF\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: "HKCR"; Subkey: "PaperPal.PDF\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; paperpal:// protocol handler (deep link)
Root: "HKCR"; Subkey: "paperpal"; ValueType: string; ValueName: ""; ValueData: "URL:PaperPal Protocol"; Flags: uninsdeletekey
Root: "HKCR"; Subkey: "paperpal"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: "HKCR"; Subkey: "paperpal\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: "HKCR"; Subkey: "paperpal\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1""""
