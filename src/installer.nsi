; DeepSeek Harness Windows installer
Unicode true
!include "MUI2.nsh"

; These can be overridden on the makensis command line:
;   makensis /DAPP_VER=1.2.3 /DOUT_FILE=... /DICON_FILE=... /DSTAGING_DIR=... src\installer.nsi
!ifndef APP_VER
  !define APP_VER "0.1.1"
!endif
!ifndef STAGING_DIR
  !define STAGING_DIR "..\work\staging"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "..\out\DeepSeekHarness-Setup-${APP_VER}.exe"
!endif
!ifndef ICON_FILE
  !define ICON_FILE "whale.ico"
!endif

!define APP_NAME "DeepSeek Harness"
!define LAUNCHER "DeepSeekHarness.exe"
!define STOPPER "DeepSeekHarnessStop.exe"

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\DeepSeekHarness"
InstallDirRegKey HKCU "Software\DeepSeekHarness" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
XPStyle on

VIProductVersion "${APP_VER}.0"
VIAddVersionKey /LANG=2052 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=2052 "FileDescription" "${APP_NAME} 安装程序"
VIAddVersionKey /LANG=2052 "FileVersion" "${APP_VER}"
VIAddVersionKey /LANG=2052 "ProductVersion" "${APP_VER}"
VIAddVersionKey /LANG=2052 "LegalCopyright" "DeepSeek"

!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "欢迎使用 ${APP_NAME} 安装向导"
!define MUI_WELCOMEPAGE_TEXT "本向导将在您的计算机上安装 ${APP_NAME}（版本 ${APP_VER}）。\r\n\r\n程序自带便携版 Node.js 运行时，安装完成后双击桌面或开始菜单中的快捷方式即可启动，无需另外安装任何东西。\r\n\r\n单击“下一步”继续，或单击“取消”退出安装。"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${LAUNCHER}"
!define MUI_FINISHPAGE_RUN_TEXT "运行 ${APP_NAME}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"


Section "${APP_NAME}" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File /r "${STAGING_DIR}\*"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\启动 ${APP_NAME}.lnk" "$INSTDIR\${LAUNCHER}" "" "$INSTDIR\whale.ico"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\关闭 ${APP_NAME}.lnk" "$INSTDIR\${STOPPER}" "" "$INSTDIR\whale.ico"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\卸载 ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\whale.ico"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "DisplayVersion" "${APP_VER}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "Publisher" "DeepSeek"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "DisplayIcon" "$INSTDIR\whale.ico"
  StrCpy $0 "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "UninstallString" '"$0"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness" "NoRepair" 1
  WriteRegStr HKCU "Software\DeepSeekHarness" "InstallDir" "$INSTDIR"
SectionEnd

Section "桌面快捷方式" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${LAUNCHER}" "" "$INSTDIR\whale.ico"
  CreateShortCut "$DESKTOP\关闭 ${APP_NAME}.lnk" "$INSTDIR\${STOPPER}" "" "$INSTDIR\whale.ico"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "${APP_NAME} 主程序，包括便携版 Node.js 运行时。"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "在桌面上创建“${APP_NAME}”和“关闭 ${APP_NAME}”两个快捷方式。"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  SetAutoClose true
  ExecWait '"$INSTDIR\${STOPPER}" /s'
  RMDir /r "$INSTDIR\node_modules"
  Delete "$INSTDIR\node.exe"
  Delete "$INSTDIR\node-license.txt"
  Delete "$INSTDIR\${LAUNCHER}"
  Delete "$INSTDIR\${STOPPER}"
  Delete "$INSTDIR\whale.ico"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APP_NAME}\*.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$DESKTOP\关闭 ${APP_NAME}.lnk"
  RMDir /r "$LOCALAPPDATA\DeepSeekHarness"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness"
  DeleteRegKey HKCU "Software\DeepSeekHarness"
SectionEnd
