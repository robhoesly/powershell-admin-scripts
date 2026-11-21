# -----------------------------
# Install ADUC snap-in and RSAT
# Active Directory Users and Computers
# Remote System Administration Tools
# (dsa.msc)
# https://theitbros.com/installing-active-directory-snap-in-on-windows/
# Windows 11 Pro
# Start powershell as local admin
# Check Execution Policy
# Run Step 1 before script
# -----------------------------

# 1. Temporary set PowerShell execution policy
set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 2. Capture Hostname info and write to computername_RSAT.txt file
$hostname = $env:COMPUTERNAME
$logPath = "$PSScriptRoot\$($hostname)_RSAT.txt"
$hostname | Out-File -FilePath $logPath -Append

# 3. Check for RSAT on computer
$RSATstatus = Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory*" | Out-File -FilePath $logPath -Append
$RSATstatus.State | Out-File -FilePath $logPath -Append
Write-Host "RSAT status logged to $logPath"

if ($RSATstatus.State -eq "Installed") {
    Write-Host "RSAT is INSTALLED." -ForegroundColor Green | Out-File -FilePath $logPath -Append
}
else {
    #If RSAT "NotPresent," install RSAT
    Write-Host "RSAT is NOT installed." -ForegroundColor Red | Out-File -FilePath $logPath -Append

    # Install ADUC Snap-in
    Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
    Write-Host "RSAT should now be installed." -ForegroundColor Green | Out-File -FilePath $logPath -Append
}

# 4. Launch ADUC mgmt console
dsa.msc

# 5. Reset PowerShell execution policy
set-ExecutionPolicy Restricted -Scope CurrentUser -Force