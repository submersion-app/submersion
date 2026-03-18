; Submersion Windows Installer
; Built by Inno Setup - https://jrsoftware.org/isinfo.php
;
; Compiled in CI via: iscc /DAPP_VERSION="1.2.5" /DAPP_VERSION_CODE="49" submersion.iss
; APP_VERSION and APP_VERSION_CODE are passed from the release workflow.

#ifndef APP_VERSION
  #define APP_VERSION "0.0.0"
#endif
#ifndef APP_VERSION_CODE
  #define APP_VERSION_CODE "0"
#endif

; Strip pre-release suffix (e.g. "1.3.3-beta.78" -> "1.3.3") for
; VersionInfoVersion, which only accepts numeric X.X.X.X format.
#define POS Pos("-", APP_VERSION)
#if POS > 0
  #define APP_VERSION_NUMERIC Copy(APP_VERSION, 1, POS - 1)
#else
  #define APP_VERSION_NUMERIC APP_VERSION
#endif

[Setup]
AppId={{B8F4E9A2-7C3D-4E1F-9A5B-2D6E8F0C1A3B}
AppName=Submersion
AppVersion={#APP_VERSION}
AppVerName=Submersion {#APP_VERSION}
AppPublisher=Eric Griffin
AppPublisherURL=https://github.com/submersion-app/submersion
AppSupportURL=https://github.com/submersion-app/submersion/issues
AppUpdatesURL=https://github.com/submersion-app/submersion/releases
DefaultDirName={autopf}\Submersion
DefaultGroupName=Submersion
LicenseFile=..\..\LICENSE
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\submersion.exe
OutputDir=..\..\build\windows\installer
OutputBaseFilename=Submersion-v{#APP_VERSION}-Windows-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
VersionInfoVersion={#APP_VERSION_NUMERIC}.{#APP_VERSION_CODE}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Submersion"; Filename: "{app}\submersion.exe"
Name: "{group}\{cm:UninstallProgram,Submersion}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Submersion"; Filename: "{app}\submersion.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\submersion.exe"; Description: "{cm:LaunchProgram,Submersion}"; Flags: nowait postinstall skipifsilent
