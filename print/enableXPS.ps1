# -----------------------------
# Check and enable XPS Viewer
# Check and enable XPS Document Writer
# Creates printer drive and object
# Windows 11 Pro
# Start powershell as local admin
# Check Execution Policy
# Run Step 1 before script
# -----------------------------

# 1. Temporary set PowerShell execution policy
set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 2. Capture Hostname info and write to computername_XPS.txt file
$hostname = $env:COMPUTERNAME
$logPath = "$PSScriptRoot\$($hostname)_XPS.txt"
$hostname | Out-File -FilePath $logPath -Append

# 3. Check for and install XPS Viewer on computer (for generated .XPS or .OXPS files)
  $XpsVstatus = Get-WindowsCapability -Online -Name "XPS.Viewer~~~~0.0.1.0" | Out-File -FilePath $logPath -Append
  $XpsVstatus.State | Out-File -FilePath $logPath -Append
  Write-Host "XPS Viewer status logged to $logPath"

if ($XpsVstatus.State -eq "Installed") {
    Write-Host "Microsoft XPS Viewer is INSTALLED." | Out-File -FilePath $logPath -Append
    Write-Host "Microsoft XPS Viewer is INSTALLED." -ForegroundColor Green
}
else {
    #If XPS Status State is "NotPresent," install XPS Viewer
    Write-Host "Microsoft XPS Viewer is NOT installed." | Out-File -FilePath $logPath -Append
    Write-Host "Microsoft XPS Viewer is NOT installed." -ForegroundColor Red

    # Use Deployment Image Servicing and Management tool to install XPS Viewer
    DISM /Online /Add-Capability /CapabilityName:XPS.Viewer~~~~0.0.1.0 | Out-File -FilePath $logPath -Append

    Write-Host "Microsoft XPS Viewer should now be installed." | Out-File -FilePath $logPath -Append
    Write-Host "XPS Document Viewer on hostname '$hostname' should now be installed." -ForegroundColor Green
}


# 4. Check for and install XPS Document Writer on computer (for generating and emailing invoices, QuickBooks)
  $XpsDWstatus = Get-WindowsOptionalFeature -Online -FeatureName Printing-XPSServices-Features | Out-File -FilePath $logPath -Append
  $XpsDWstatus.State | Out-File -FilePath $logPath -Append
    # Alternative installation method:
    # DISM /Online /Get-Features /Format:Table | findstr "Printing-XPSServices-Features" | Out-File -FilePath $logPath -Append
  Write-Host "Microsoft XPS Document Writer status logged to $logPath" | Out-File -FilePath $logPath -Append

if ($XpsDWstatus.State -eq "Installed") {
    Write-Host "Microsoft XPS Document Writer is INSTALLED." | Out-File -FilePath $logPath -Append
    Write-Host "Microsoft XPS Document Writer is INSTALLED." -ForegroundColor Green
}
else {
  #If XPS Document Writer Status State is "NotPresent," install XPS Document Writer
    Write-Host "Microsoft XPS Document Writer is NOT installed." | Out-File -FilePath $logPath -Append
    Write-Host "Microsoft XPS Document Writer is NOT installed." -ForegroundColor Red

    #Enable XPS Document Writer
    Enable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features" -All -NoRestart | Out-File -FilePath $logPath -Append
 
    Write-Host "Microsoft XPS Document Writer should now be installed." | Out-File -FilePath $logPath -Append
    Write-Host "XPS Document Viewer on hostname '$hostname' should now be installed." -ForegroundColor Green

    # Create print driver and printer object
    Add-PrinterDriver -Name "Microsoft XPS Document Writer v4"
    Add-Printer -Name "Microsoft XPS Document Writer" -DriverName "Microsoft XPS Document Writer v4" -PortName "portprompt:"
 
    Write-Host "Printer Driver and Printer should now be installed." | Out-File -FilePath $logPath -Append
    Write-Host "Printer Driver and Printer on hostname '$hostname' should now be installed." -ForegroundColor Green
}

# 5. Reset PowerShell execution policy
set-ExecutionPolicy Restricted -Scope CurrentUser -Force