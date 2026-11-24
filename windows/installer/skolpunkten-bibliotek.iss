; Installationsprogram för Skolpunkten Bibliotek (Inno Setup 6).
;
; Byggs av .github/workflows/build-windows.yml:
;   ISCC.exe /DAppVersion=1.0.0 /DSourceDir=<Release-mappen> /DOutputDir=<ut> skolpunkten-bibliotek.iss
;
; Installerar för alla användare under C:\Program Files\Skolpunkten Bibliotek —
; samma sökväg som README använder för Shell Launcher (kioskkonto).

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif

#define AppName "Skolpunkten Bibliotek"
; Release-bygget döps om till skolpunkten.exe i windows/CMakeLists.txt.
#define AppExe "skolpunkten.exe"

[Setup]
; Fast AppId — samma för alla versioner, så att en ny version ersätter den gamla.
AppId={{6B1E3C52-8E2D-4C6A-9F3B-5A7D2E1C9B40}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Skolpunkten
AppPublisherURL=https://skolpunkten.se
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=Skolpunkten-Bibliotek-setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
; Stäng appen om den är igång vid uppdatering.
CloseApplications=yes
RestartApplications=no

[Languages]
; Svenska finns i nyare Inno Setup 6 — annars engelska.
#if FileExists(AddBackslash(CompilerPath) + "Languages\Swedish.isl")
Name: "swedish"; MessagesFile: "compiler:Languages\Swedish.isl"
#else
Name: "english"; MessagesFile: "compiler:Default.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "Skapa en genväg på skrivbordet"; GroupDescription: "Genvägar:"
Name: "autostart"; Description: "Starta biblioteket när någon loggar in på datorn"; GroupDescription: "Start:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Avinstallera {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon
Name: "{commonstartup}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: autostart

[Run]
Filename: "{app}\{#AppExe}"; Description: "Starta {#AppName}"; Flags: nowait postinstall skipifsilent
