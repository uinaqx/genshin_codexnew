#ifndef AppVersion
  #define AppVersion "2.0.0"
#endif

#define AppName "可莉 Codex 安全中心"
#define AppPublisher "uinaqx"
#define AppURL "https://github.com/uinaqx/genshin_codexnew"

[Setup]
AppId={{1AAF7D01-75F6-407A-BE69-C7E33A663493}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={localappdata}\Programs\KleeCodexSafety
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=output
OutputBaseFilename=KleeCodexSafety-Setup-v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
UninstallDisplayName={#AppName}
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName}
VersionInfoCompany={#AppPublisher}
VersionInfoCopyright=MIT licensed software; character rights belong to their respective owners

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "其他选项："; Flags: unchecked

[Files]
Source: "payload\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: filesandordirs; Name: "{localappdata}\Programs\KleeCodexSkin"
Type: filesandordirs; Name: "{app}\assets"
Type: filesandordirs; Name: "{app}\scripts"
Type: filesandordirs; Name: "{app}\styles"
Type: filesandordirs; Name: "{app}\runtime"
Type: filesandordirs; Name: "{app}\manager"
Type: filesandordirs; Name: "{app}\windows"
Type: filesandordirs; Name: "{app}\themes"
Type: filesandordirs; Name: "{app}\schema"
Type: filesandordirs; Name: "{app}\docs"
Type: files; Name: "{app}\quickstart.ps1"
Type: files; Name: "{app}\quick-theme.ps1"
Type: files; Name: "{userprograms}\可莉 Codex 皮肤管理器.lnk"
Type: files; Name: "{userdesktop}\可莉 Codex 皮肤管理器.lnk"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{{D3A25C8C-75CC-44AF-9F8A-98A8E7FA2B40}_is1"; Flags: deletekey

[Icons]
Name: "{userprograms}\{#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSafetyCenter.ps1"""; WorkingDir: "{app}"
Name: "{userdesktop}\{#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSafetyCenter.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSafetyCenter.ps1"""; WorkingDir: "{app}"; Description: "打开可莉 Codex 安全中心"; Flags: nowait postinstall skipifsilent
