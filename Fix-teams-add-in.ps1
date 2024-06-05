# Fix Microsoft Teams Meeting Add-in for Microsoft Office 
# Remy Kuster
# www.iamsysadmin.eu

$ApplicationMSIGUID = "{A7AB73A3-CB10-4AA5-9D38-6AEFFBDE4C91}"

Stop-Process -Name OUTLOOK -Force
Stop-Process -Name ms-teams -Force


Start-Process msiexec.exe -wait -ArgumentList "/f $ApplicationMSIGUID /quiet /norestart" | Out-Null


Start-Process -FilePath "C:\Program Files\WindowsApps\MSTeams_24102.2223.2870.9480_x64__8wekyb3d8bbwe\ms-teams.exe"

Start-Sleep 10

Start-Process -FilePath "C:\Program Files (x86)\Microsoft Office\root\Office16\OUTLOOK.EXE"

New-Item -Path $env:LOCALAPPDATA -Name "TeamsRepairAdd-in" -ItemType Directory
New-Item -Path $env:LOCALAPPDATA\TeamsRepairAdd-in -Name "installed.txt" -ItemType File
