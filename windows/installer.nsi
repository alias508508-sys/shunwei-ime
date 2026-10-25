Unicode true
!include "MUI2.nsh"
!include "x64.nsh"
Name "顺位输入法（开发版）"
OutFile "../releases/Shunwei-0.2.0-dev-Windows-Setup.exe"
InstallDir "$PROGRAMFILES64\ShunweiIME"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "顺位输入法 · 系统输入法开发版"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "这是顺位 TSF 系统输入法开发版，默认拼音。支持64位Windows中的64位和32位桌面程序。$\r$\n$\r$\n本包在Mac交叉编译，尚未在Windows实机验证。请先在测试电脑或虚拟机使用。$\r$\n$\r$\n安装后需要在Windows中文输入选项中手动添加顺位。本安装器不会自动替换当前输入法。"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "此开发包需要x64 Windows。32位系统和ARM原生平台暂不支持。"
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd
Section "安装系统输入法"
  IfFileExists "$INSTDIR\*.*" 0 +3
    MessageBox MB_ICONSTOP "目标文件夹非空，请选择新文件夹；升级请先卸载旧版。"
    Abort
  SetOutPath "$INSTDIR\x64"
  File "build/x64/Shunwei.dll"
  File "build/x64/engine-check.exe"
  File /r "build/data"
  SetOutPath "$INSTDIR\x86"
  File "build/x86/Shunwei.dll"
  File "build/x86/engine-check.exe"
  File /r "build/data"
  SetOutPath "$INSTDIR\ThirdParty"
  File "../docs/THIRD_PARTY_NOTICES.md"
  File "../docs/sources.json"
  File "../data/upstream/jieba-LICENSE"
  File "../data/upstream/cmudict-LICENSE"
  File /r "ThirdParty"
  SetOutPath "$INSTDIR"
  File /oname=使用说明.md "../docs/windows-install.md"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  ClearErrors
  ${DisableX64FSRedirection}
  ExecWait '"$SYSDIR\regsvr32.exe" /s "$INSTDIR\x64\Shunwei.dll"' $0
  ${EnableX64FSRedirection}
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "64位组件注册失败（$0）。安装未完成，请运行卸载或联系开发者。"
    SetErrorLevel 1
    Abort
  ${EndIf}
  ExecWait '"$WINDIR\SysWOW64\regsvr32.exe" /s "$INSTDIR\x86\Shunwei.dll"' $0
  ${If} $0 != 0
    ${DisableX64FSRedirection}
    ExecWait '"$SYSDIR\regsvr32.exe" /u /s "$INSTDIR\x64\Shunwei.dll"'
    ${EnableX64FSRedirection}
    MessageBox MB_ICONSTOP "32位组件注册失败（$0）。64位组件已尝试回滚。"
    SetErrorLevel 1
    Abort
  ${EndIf}
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShunweiIME" "DisplayName" "顺位输入法（开发版）"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShunweiIME" "DisplayVersion" "0.2.0-dev"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShunweiIME" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShunweiIME" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShunweiIME" "NoRepair" 1
SectionEnd
Section "Uninstall"
  SetRegView 64
  MessageBox MB_OKCANCEL "请先切换到其他输入法，并从Windows语言设置移除顺位。继续卸载？" IDOK +2
  Abort
  SetOverwrite off
  ${DisableX64FSRedirection}
  ExecWait '"$SYSDIR\regsvr32.exe" /u /s "$INSTDIR\x64\Shunwei.dll"'
  ${EnableX64FSRedirection}
  ExecWait '"$WINDIR\SysWOW64\regsvr32.exe" /u /s "$INSTDIR\x86\Shunwei.dll"'
  Delete /REBOOTOK "$INSTDIR\x64\Shunwei.dll"
  Delete /REBOOTOK "$INSTDIR\x86\Shunwei.dll"
  Delete "$INSTDIR\x64\engine-check.exe"
  Delete "$INSTDIR\x86\engine-check.exe"
  RMDir /r "$INSTDIR\x64\data"
  RMDir /r "$INSTDIR\x86\data"
  RMDir "$INSTDIR\x64"
  RMDir "$INSTDIR\x86"
  RMDir /r "$INSTDIR\ThirdParty"
  Delete "$INSTDIR\使用说明.md"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ShunweiIME"
SectionEnd
