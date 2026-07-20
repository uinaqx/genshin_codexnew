#ifndef AppVersion
  #define AppVersion "1.1.2"
#endif

#define AppName "可莉 Codex 皮肤管理器"
#define AppPublisher "uinaqx"
#define AppURL "https://github.com/uinaqx/genshin_codexnew"

[Setup]
AppId={{D3A25C8C-75CC-44AF-9F8A-98A8E7FA2B40}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
DefaultDirName={localappdata}\Programs\KleeCodexSkin
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=output
OutputBaseFilename=KleeCodexSkin-Setup-v{#AppVersion}
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

[Icons]
Name: "{userprograms}\{#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSkinManager.ps1"""; WorkingDir: "{app}"
Name: "{userdesktop}\{#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSkinManager.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSkinManager.ps1"" -EmergencyRecover"; WorkingDir: "{app}"; Flags: nowait

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\manager\KleeSkinManager.ps1"" -PrepareUninstall -NonInteractive"; WorkingDir: "{app}"; Flags: runhidden waituntilterminated; RunOnceId: "RestoreOfficialCodex"

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\CodexDreamSkin"
