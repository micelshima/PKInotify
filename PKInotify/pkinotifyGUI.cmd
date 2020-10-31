@ECHO OFF
if %computername:~0,2%==SV goto fromserver
pwsh -noprofile -executionpolicy unrestricted -WINDOWSTYLE HIDDEN -file "%~dp0\pkinotifyGUI.ps1" || powershell_ise "%~dp0\pkinotifyGUI.ps1" -noprofile
exit
:fromserver
powershell -noprofile -executionpolicy unrestricted -WINDOWSTYLE HIDDEN -file "%~dp0\pkinotifyGUI.ps1"
exit


