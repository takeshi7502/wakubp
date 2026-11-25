@echo off
start "" wscript.exe //nologo "%~dp0src\launch.vbs" || start "" powershell.exe -STA -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0src\gui.ps1"
exit

