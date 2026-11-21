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

# Initialize Logging in the same folder where the script is located
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\Temp" }
if (-not (Test-Path $ScriptDir)) { New-Item -Path $ScriptDir -ItemType Directory -Force | Out-Null }
$logPath = Join-Path -Path $ScriptDir -ChildPath "winget_silent.log"

Start-Transcript -Path $logPath -Force
Write-Host "Logging session output to: $logPath" -ForegroundColor Cyan

Try {
    Write-Host "Configuring Script Environment..." -ForegroundColor Cyan
    $ErrorActionPreference = "Continue"

    # PowerShell execution policy configurations (Safe when launched with -ExecutionPolicy Bypass)
    Write-Host "Checking execution policies..." -ForegroundColor Gray
    Get-ExecutionPolicy -List
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        Write-Host "Execution policy is currently managed by process/machine scope (Bypass). Continuing..." -ForegroundColor Gray
    }

    # Check for WinGet (If missing, attempt App Installer registration)
    Write-Host "Verifying Windows Package Manager (WinGet)..." -ForegroundColor Gray
    $wingetCheck = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCheck) {
        Write-Warning "WinGet is not available. Running baseline setup handlers..."
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "WinGet Framework detected. Version: $(winget --version)" -ForegroundColor Green
        
        Write-Host "Resetting and updating WinGet sources..." -ForegroundColor Gray
        winget source reset --force
        winget source update
    } else {
        Write-Error "CRITICAL: WinGet initialization failed. Skipping WinGet layers."
    }

    # Set/confirm Geographic region code
    Write-Host "Enforcing system regional baseline (en-US)..." -ForegroundColor Gray
    Set-WinSystemLocale en-US -ErrorAction SilentlyContinue
    Set-Culture en-US -ErrorAction SilentlyContinue

    # ==============================================================================
    # 1. Upgrade software components via standard WinGet repositories
    # ==============================================================================
    Write-Host "`nStep 1/7: Checking for all WinGet community package updates..." -ForegroundColor Cyan
    winget upgrade --all --source winget --include-unknown --silent --accept-source-agreements --accept-package-agreements

    # ==============================================================================
    # 2. Upgrade software components via Microsoft Store & Native Store Scan
    # ==============================================================================
    Write-Host "`nStep 2/7: Checking for Microsoft Store package updates..." -ForegroundColor Cyan
    winget upgrade --all --source msstore --include-unknown --silent --accept-source-agreements --accept-package-agreements

    Write-Host "Triggering native Microsoft Store background update scan..." -ForegroundColor Gray
    try {
        $storeScan = Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction Stop
        $storeScan | Invoke-CimMethod -MethodName UpdateScanMethod | Out-Null
        Write-Host "Native Microsoft Store scan triggered successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Could not trigger CIM Store scan (may require user session context): $_"
    }

    # ==============================================================================
    # 3. Trigger Microsoft Office (Click-to-Run) Updates
    # ==============================================================================
    Write-Host "`nStep 3/7: Checking for Microsoft 365 / Office Click-to-Run updates..." -ForegroundColor Cyan
    $OfficeC2R = "$env:CommonProgramFiles\microsoft shared\ClickToRun\OfficeC2RClient.exe"
    if (Test-Path $OfficeC2R) {
        Write-Host "Office Click-to-Run client found. Triggering silent update check..." -ForegroundColor Gray
        Start-Process -FilePath $OfficeC2R -ArgumentList "/update user displaylevel=false forceappshutdown=false" -Wait
        Write-Host "Office update check completed." -ForegroundColor Green
    } else {
        Write-Host "Office Click-to-Run client not detected. Skipping." -ForegroundColor Gray
    }

    # ==============================================================================
    # 4. Enforce Device Metadata & Driver Blocking Settings
    # ==============================================================================
    Write-Host "`nStep 4/7: Enforcing device installations and driver restrictions..." -ForegroundColor Cyan
    $MetadataPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata"
    $DriverBlockPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"

    if (Test-Path $MetadataPath) {
        New-ItemProperty -Path $MetadataPath -Name "PreventDeviceMetadataFromNetwork" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    if (Test-Path $DriverBlockPath) {
        New-ItemProperty -Path $DriverBlockPath -Name "SearchOrderConfig" -Value 0 -PropertyType DWord -Force | Out-Null
    }
    Write-Host "Driver searching and manufacturer companion metadata blocked." -ForegroundColor Green

    # ==============================================================================
    # 5. Enforce Target Release Version Lock (Allowing Windows 11 26H2)
    # ==============================================================================
    Write-Host "`nStep 5/7: Hardening Feature Update Policy (Allowing Windows 11 26H2)..." -ForegroundColor Cyan
    $WUKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

    if (-not (Test-Path $WUKeyPath)) {
        New-Item -Path $WUKeyPath -Force | Out-Null
    }

    New-ItemProperty -Path $WUKeyPath -Name "TargetReleaseVersion" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $WUKeyPath -Name "ProductVersion" -Value "Windows 11" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $WUKeyPath -Name "TargetReleaseVersionInfo" -Value "26H2" -PropertyType String -Force | Out-Null

    Write-Host "Target Release Baseline successfully locked to Windows 11 26H2." -ForegroundColor Green

    # ==============================================================================
    # 6. Windows Update Integration (All OS, Cumulative & Security Updates - No Drivers)
    # ==============================================================================
    Write-Host "`nStep 6/7: Triggering Windows Operating System, Cumulative & Security updates..." -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "PSWindowsUpdate module not found. Installing silently from PSGallery..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -AllowClobber -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
    }

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Error "CRITICAL: Failed to load PSWindowsUpdate. Core OS patching skipped."
    } else {
        Write-Host "Importing PSWindowsUpdate and scanning Microsoft Update servers..." -ForegroundColor Gray
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

        # Exclude Drivers (handled by Step 4), but capture all Cumulative, Security, Defender, and .NET updates
        $installedUpdates = Get-WindowsUpdate -MicrosoftUpdate -NotCategory "Drivers" -AcceptAll -Install -IgnoreReboot -Verbose
    }

    # ==============================================================================
    # 7. Intelligent Evaluation Loop & Machine Reboot Handlers
    # ==============================================================================
    Write-Host "`nStep 7/7: Evaluating system reboot criteria..." -ForegroundColor Cyan
    $rebootPending = Get-WURebootStatus -Silent -ErrorAction SilentlyContinue

    if ($rebootPending -or ($installedUpdates | Where-Object { $_.RebootRequired -eq $true })) {
        Write-Host "========================================================================" -ForegroundColor Yellow
        Write-Host " ATTENTION: Newly installed updates require a system reboot to complete." -ForegroundColor Yellow
        Write-Host " System will cleanly reboot in 30 seconds..." -ForegroundColor Red
        Write-Host " Press [Ctrl+C] inside this window immediately to abort the restart sequence." -ForegroundColor Gray
        Write-Host "========================================================================" -ForegroundColor Yellow
        Stop-Transcript
        Start-Sleep -Seconds 30
        Write-Host "Initiating clean system reboot now..." -ForegroundColor Red
        Restart-Computer -Force
    } else {
        Write-Host "No reboot required by newly installed updates. Finalizing process." -ForegroundColor Green
        Write-Host "Script finished and updates complete. Closing in 10 seconds..." -ForegroundColor Cyan
        Stop-Transcript
        Start-Sleep -Seconds 10
    }
}
Catch {
    Write-Error "An unexpected error occurred: $_"
    Stop-Transcript -ErrorAction SilentlyContinue
}
