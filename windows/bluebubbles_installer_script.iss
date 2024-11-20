; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "BlueBubbles"
#define MyAppVersion "1.15.1.0"
#define MyAppPublisher "BlueBubbles"
#define MyAppURL "https://bluebubbles.app/"
#define MyAppExeName "bluebubbles_app.exe"
#define ProjectRoot ".."

#include "CodeDependencies.iss"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{6129D070-FCBC-4167-8C1F-9A4B18263EFF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Uncomment the following line to run in non administrative install mode (install for current user only.)
;PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=.
OutputBaseFilename=bluebubbles-windows
SetupIconFile={#ProjectRoot}\assets\icon\icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Code]
function InitializeSetup: Boolean;
begin
  if not IsMsiProductInstalled('{36F68A90-239C-34DF-B58C-64B30153CE35}', PackVersionComponents(14, 40, 33810, 0)) then begin
    Dependency_Add('vcredist2022 (x64).exe',
      '/passive /norestart',
      'Visual C++ 2015-2022 Redistributable (x64)',
      'https://aka.ms/vs/17/release/vc_redist.x64.exe',
      '', False, False);
  end;
  Result := True;
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\*.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\*.exp"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
// Source: "{#ProjectRoot}\windows\dlls\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\imessage"; ValueType: "string"; ValueData: "URL:iMessage Protocol"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\imessage"; ValueType: "string"; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\imessage\DefaultIcon"; ValueType: "string"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\imessage\shell\open\command"; ValueType: "string"; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
