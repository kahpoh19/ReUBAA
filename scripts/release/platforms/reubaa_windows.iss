; ReUBAA 的 Windows 安装器。AppId 和安装目录都和原版 UBAA 分开，两个可以同时装。
; 可执行文件名沿用 UBAA.exe（构建产物没改名），快捷方式和卸载项显示 ReUBAA。
#ifndef AppVersion
  #error AppVersion 必须由发布工作流提供
#endif
[Setup]
AppId={{160306A0-570E-4043-9359-8964DA9B4207}
AppName=ReUBAA
AppVersion={#AppVersion}
AppPublisher=ReUBAA
DefaultDirName={localappdata}\Programs\ReUBAA
DefaultGroupName=ReUBAA
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=../../../.ubaa_local/release/public
OutputBaseFilename=ReUBAA-{#AppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\UBAA.exe
UninstallDisplayName=ReUBAA
[Files]
Source: "../../../apps/ubaa_flutter/build/windows/x64/runner/Release/*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\ReUBAA"; Filename: "{app}\UBAA.exe"
Name: "{autodesktop}\ReUBAA"; Filename: "{app}\UBAA.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; Flags: unchecked
[Run]
Filename: "{app}\UBAA.exe"; Description: "启动 ReUBAA"; Flags: nowait postinstall skipifsilent
