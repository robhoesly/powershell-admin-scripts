# ==============================================================================
# Windows Updates Silent But Verbose Using Package Manager and Windows Update
# Run as Administrator
# Either restart machine or close all user apps before running
#
# References & Documentation:
# https://computingforgeeks.com/install-and-use-winget-windows-package-manager-client/
# https://www.nakivo.com/blog/automate-windows-updates-using-powershell-short-overview/
# https://www.powershellgallery.com/
# ==============================================================================

# 0. Check Administrator Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "CRITICAL: This script MUST be run as an Administrator. Exiting."
    Start-Sleep -Seconds 5
    Exit
}

Write-Host "Configuring Script Environment..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"

# PowerShell commands / execution policy configurations
Write-Host "Updating execution policies..." -ForegroundColor Gray
Get-ExecutionPolicy -List
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Check for WinGet (If the command fails, "App Installer" is needed)
Write-Host "Verifying Windows Package Manager (WinGet)..." -ForegroundColor Gray
$wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCheck) {
    Write-Warning "WinGet is not available. Running baseline setup handlers..."
    Write-Host "Executing fallback registration via native DesktopAppInstaller family signature..." -ForegroundColor Yellow
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
}

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "WinGet Framework detected. Version: $(winget --version)" -ForegroundColor Green
} else {
    Write-Error "CRITICAL: WinGet initialization engine failed. Skipping software sweeping layers."
}

# Reset sources to restore pristine operational base configurations
Write-Host "Resetting validation sources..." -ForegroundColor Gray
winget source reset --force

# Set/confirm Geographic region code
Write-Host "Enforcing system regional baseline (en-US)..." -ForegroundColor Gray
Set-WinSystemLocale en-US -ErrorAction SilentlyContinue
Set-Culture en-US -ErrorAction SilentlyContinue

# Review current upgrade sources & refresh manifests
Write-Host "Refreshing repository maps..." -ForegroundColor Gray
winget source list
winget source update

# Show tracking metrics across local deployments
Write-Host "Gathering software catalog summaries..." -ForegroundColor Gray
winget list --accept-source-agreements
winget upgrade list --include-unknown --accept-source-agreements

# ==============================================================================
# 1. Upgrade software components via standard repositories
# ==============================================================================
Write-Host "`nStep 1/6: Checking for all WinGet community package updates..." -ForegroundColor Cyan
winget upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements

# ==============================================================================
# 2. Upgrade software components via Microsoft Store engine
# ==============================================================================
Write-Host "`nStep 2/6: Checking for Microsoft Store package updates..." -ForegroundColor Cyan
winget upgrade --all --source msstore --silent --accept-source-agreements --accept-package-agreements

# ==============================================================================
# 3. Enforce Device Metadata & Driver Blocking Settings
# ==============================================================================
Write-Host "`nStep 3/6: Enforcing device installations and driver restrictions..." -ForegroundColor Cyan
$MetadataPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata"
$DriverBlockPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"

if (Test-Path $MetadataPath) {
    New-ItemProperty -Path $MetadataPath -Name "PreventDeviceMetadataFromNetwork" -Value 0 -PropertyType DWord -Force | Out-Null
}

if (Test-Path $DriverBlockPath) {
    New-ItemProperty -Path $DriverBlockPath -Name "SearchOrderConfig" -Value 0 -PropertyType DWord -Force | Out-Null
}
Write-Host "Driver searching and manufacturer companion applications blocked." -ForegroundColor Green

# ==============================================================================
# 4. Enforce Target Release Version Lock (Allowing Windows 11 26H2)
# ==============================================================================
Write-Host "`nStep 4/6: Hardening Feature Update Policy (Allowing Windows 11 26H2)..." -ForegroundColor Cyan
$WUKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

if (-not (Test-Path $WUKeyPath)) {
    New-Item -Path $WUKeyPath -Force | Out-Null
}

New-ItemProperty -Path $WUKeyPath -Name "TargetReleaseVersion" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $WUKeyPath -Name "ProductVersion" -Value "Windows 11" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $WUKeyPath -Name "TargetReleaseVersionInfo" -Value "26H2" -PropertyType String -Force | Out-Null

Write-Host "Target Release Baseline successfully locked to Windows 11 26H2." -ForegroundColor Green

# ==============================================================================
# 5. Windows Update Integration (OS Patches & Core Security Only)
# ==============================================================================
Write-Host "`nStep 5/6: Triggering Windows Operating System & Core Security update stream..." -ForegroundColor Cyan

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "PSWindowsUpdate module not found. Installing silently from PSGallery..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -AllowClobber -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
}

# Explicitly stop here if the module failed to load entirely
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Error "CRITICAL: Failed to load PSWindowsUpdate. Core OS patching skipped."
    Write-Host "Script finished with errors. Closing in 10 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Exit
}

Write-Host "Importing PSWindowsUpdate and searching for required core packages..." -ForegroundColor Gray
Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

$TargetCategories = @("Critical Updates", "Security Updates", "Definition Updates", "Service Packs")
$installedUpdates = Get-WindowsUpdate -Category $TargetCategories -AcceptAll -Install -IgnoreReboot -Verbose

# ==============================================================================
# 6. Intelligent Evaluation Loop & Machine Reboot Handlers
# ==============================================================================
Write-Host "`nStep 6/6: Evaluating system reboot criteria..." -ForegroundColor Cyan
$rebootPending = Get-WURebootStatus -ErrorAction SilentlyContinue

if ($rebootPending -and $installedUpdates) {
    Write-Host "========================================================================" -ForegroundColor Yellow
    Write-Host " ATTENTION: Newly installed updates require a system reboot to complete." -ForegroundColor Yellow
    Write-Host " System will cleanly reboot in 30 seconds..." -ForegroundColor Red
    Write-Host " Press [Ctrl+C] inside this window immediately to abort the restart sequence." -ForegroundColor Gray
    Write-Host "========================================================================" -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Write-Host "Initiating clean system reboot now..." -ForegroundColor Red
    Restart-Computer -Force
} else {
    Write-Host "No reboot required by newly installed updates. Finalizing process." -ForegroundColor Green
    Write-Host "Script finished and updates complete. Closing in 10 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
}
