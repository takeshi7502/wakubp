' ==============================================================================
' wakubp :: ZERO-FLASH GUI HELPER (src\launch.vbs)
' Invoked by wakubp.bat via wscript.exe to spawn PowerShell WinForms with SW_HIDE
' ==============================================================================
Option Explicit

Dim sh, fso, srcDir, cmd
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

srcDir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd    = "powershell.exe -STA -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & srcDir & "\gui.ps1"""

sh.Run cmd, 0, False
