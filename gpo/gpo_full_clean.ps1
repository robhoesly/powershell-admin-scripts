# ============================================================================
# Windows 11 - Post-AD Workgroup Cleanup
#
# Purpose:
#   Clean up residual Group Policy data after removing a computer from AD
#   and restore normal Windows Update behavior.
#
# Run from an elevated PowerShell session.
# ============================================================================

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Post-AD Workgroup Cleanup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ----------------------------------------------------------------------------
# 1. Confirm the computer is no longer domain-joined
# ----------------------------------------------------------------------------

$computerSystem = Get-CimInstance Win32_ComputerSystem

if ($computerSystem.PartOfDomain) {
    Write-Warning "This computer still reports that it is domain-joined."
    Write-Warning "Aborting cleanup."
    exit 1
}

Write-Host "Computer is in workgroup: $($computerSystem.Workgroup)" -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------------------------------
# 2. Remove Group Policy history
# ----------------------------------------------------------------------------

Write-Host "Removing Group Policy history..." -ForegroundColor Yellow

$gpHistory = Join-Path $env:ALLUSERSPROFILE 'Microsoft\Group Policy\History'

if (Test-Path $gpHistory) {
    Remove-Item "$gpHistory\*" -Recurse -Force
}

# ----------------------------------------------------------------------------
# 3. Remove the local Group Policy cache
#
#    GroupPolicy\Machine and GroupPolicy\User contain locally cached
#    policy data. Windows can recreate these as needed.
# ----------------------------------------------------------------------------

Write-Host "Removing local Group Policy cache..." -ForegroundColor Yellow

$gpPath = Join-Path $env:WINDIR 'System32\GroupPolicy'

if (Test-Path $gpPath) {
    Remove-Item "$gpPath\*" -Recurse -Force
}

# ----------------------------------------------------------------------------
# 4. Purge Kerberos tickets
# ----------------------------------------------------------------------------

Write-Host "Purging Kerberos tickets..." -ForegroundColor Yellow

klist purge

# ----------------------------------------------------------------------------
# 5. Remove Windows Update policy settings
#
#    These are much narrower than deleting:
#
#      HKLM\Software\Policies\Microsoft
#
#    The latter contains many unrelated policies.
#
#    Remove only the Windows Update policy branches.
# ----------------------------------------------------------------------------

Write-Host "Removing Windows Update policy settings..." -ForegroundColor Yellow

$windowsUpdatePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$windowsUpdateAU     = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

if (Test-Path $windowsUpdateAU) {
    Remove-Item $windowsUpdateAU -Recurse -Force
}

if (Test-Path $windowsUpdatePolicy) {
    Remove-Item $windowsUpdatePolicy -Recurse -Force
}

# ----------------------------------------------------------------------------
# 6. Remove Windows Update policy settings under the current user's profile
#
#    This is intentionally limited to the Windows Update policy branch.
# ----------------------------------------------------------------------------

$currentUserWU = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

if (Test-Path $currentUserWU) {
    Remove-Item $currentUserWU -Recurse -Force
}

# ----------------------------------------------------------------------------
# 7. Ensure Windows Update services are enabled
# ----------------------------------------------------------------------------

Write-Host "Checking Windows Update services..." -ForegroundColor Yellow

$services = @(
    'wuauserv',
    'BITS',
    'UsoSvc'
)

foreach ($serviceName in $services) {

    $service = Get-Service -Name $serviceName

    if ($null -ne $service) {

        try {
            Set-Service -Name $serviceName -StartupType Manual
        }
        catch {
            Write-Warning "Could not change startup type for $serviceName"
        }
    }
}

# ----------------------------------------------------------------------------
# 8. Start the services
# ----------------------------------------------------------------------------

Write-Host "Starting Windows Update services..." -ForegroundColor Yellow

foreach ($serviceName in $services) {

    try {
        Start-Service -Name $serviceName
    }
    catch {
        Write-Warning "Could not start $serviceName"
    }
}

# ----------------------------------------------------------------------------
# 9. Refresh Group Policy
#
#    The machine is now in a workgroup, so there should be no domain GPO
#    to download. This causes Windows to process whatever local policy
#    remains.
# ----------------------------------------------------------------------------

Write-Host "Refreshing policy..." -ForegroundColor Yellow

gpupdate /force

# ----------------------------------------------------------------------------
# 10. Display Windows Update policy values for verification
# ----------------------------------------------------------------------------

Write-Host ""
Write-Host "Windows Update policy verification:" -ForegroundColor Cyan

if (Test-Path $windowsUpdatePolicy) {
    Get-ItemProperty $windowsUpdatePolicy |
        Select-Object * |
        Format-List
}
else {
    Write-Host "No Windows Update policy key remains." -ForegroundColor Green
}

# ----------------------------------------------------------------------------
# 11. Final status
# ----------------------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Cleanup complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "A reboot is recommended."
Write-Host ""
Write-Host "After reboot, verify Windows Update manually."
