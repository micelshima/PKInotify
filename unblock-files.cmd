powershell -command "&{gci .\ -recurse|Unblock-File -confirm:$false}"
pause