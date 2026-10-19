Unicode true
!include "MUI2.nsh"
!include "WinMessages.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "StrFunc.nsh"
${StrStr}
${UnStrRep}
!insertmacro GetParameters
!insertmacro GetOptions

Name "Net-SNMP ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\Net-SNMP"
InstallDirRegKey HKLM "Software\Net-SNMP" "InstallDir"
RequestExecutionLevel admin

!insertmacro MUI_PAGE_LICENSE "..\COPYING"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Net-SNMP" SecMain
    SectionIn RO
    SetOutPath "$INSTDIR"
    File /r "${PAYLOAD}\*.*"
    CreateDirectory "$INSTDIR\etc\snmp"

    WriteRegStr HKLM "Software\Net-SNMP" "InstallDir" "$INSTDIR"

    ; The executables are built for a POSIX-style prefix, so point them at the install dir.
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "MIBDIRS" "$INSTDIR\share\snmp\mibs"
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "SNMPCONFPATH" "$INSTDIR\etc\snmp"
    ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
    ${StrStr} $1 "$0" "$INSTDIR\bin"
    ${If} $1 == ""
        WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$0;$INSTDIR\bin;$INSTDIR\sbin"
    ${EndIf}
    SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=5000

    WriteUninstaller "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Net-SNMP" "DisplayName" "Net-SNMP ${VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Net-SNMP" "DisplayVersion" "${VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Net-SNMP" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Net-SNMP" "NoModify" 1
SectionEnd

; Off by default. Silent install: /SERVICE=1
Section /o "Windows service for snmpd (starts at boot)" SecService
    nsExec::ExecToLog '"$INSTDIR\sbin\snmpd.exe" -register -quiet'
    Pop $0
SectionEnd

Function .onInit
    ${GetParameters} $R0
    ${GetOptions} $R0 "/SERVICE=" $R1
    ${If} $R1 == "1"
        !insertmacro SelectSection ${SecService}
    ${EndIf}
FunctionEnd

Section "Uninstall"
    ; Stops and removes the services if they were registered; harmless otherwise.
    nsExec::ExecToLog '"$INSTDIR\sbin\snmpd.exe" -unregister -quiet'
    Pop $0
    nsExec::ExecToLog '"$INSTDIR\sbin\snmptrapd.exe" -unregister -quiet'
    Pop $0
    ; Remove only our own PATH entries.
    ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
    ${UnStrRep} $0 "$0" ";$INSTDIR\bin;$INSTDIR\sbin" ""
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$0"
    DeleteRegValue HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "MIBDIRS"
    DeleteRegValue HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "SNMPCONFPATH"
    SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=5000

    ; Keep user configuration: remove only what the installer put there.
    RMDir /r "$INSTDIR\bin"
    RMDir /r "$INSTDIR\sbin"
    RMDir /r "$INSTDIR\share"
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR\etc\snmp"
    RMDir "$INSTDIR\etc"
    RMDir "$INSTDIR"
    DeleteRegKey HKLM "Software\Net-SNMP"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Net-SNMP"
SectionEnd
