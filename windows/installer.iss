; Installer Windows di AcidTalk (Inno Setup 6). Usato dalla GitHub Action:
;   ISCC.exe /DAppVersion=2.4.0 /DSourceDir=...\Release /O<dist> windows\installer.iss
#ifndef AppVersion
  #define AppVersion "2.4.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{6F3C2A51-8A4E-4C1B-9D9B-2B7F4C0E5A17}
AppName=AcidTalk
AppVersion={#AppVersion}
AppPublisher=AcidSoft
DefaultDirName={autopf}\AcidTalk
DefaultGroupName=AcidTalk
UninstallDisplayIcon={app}\acidtalk.exe
OutputBaseFilename=AcidTalk-windows-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile=runner\resources\app_icon.ico
WizardStyle=modern

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AcidTalk"; Filename: "{app}\acidtalk.exe"; AppUserModelID: "it.acidsoft.acidtalk"
Name: "{autodesktop}\AcidTalk"; Filename: "{app}\acidtalk.exe"; Tasks: desktopicon; AppUserModelID: "it.acidsoft.acidtalk"

[Run]
Filename: "{app}\acidtalk.exe"; Description: "{cm:LaunchProgram,AcidTalk}"; Flags: nowait postinstall skipifsilent
