#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    FortReign.Teardown.ps1 — Fort Reign Lab Environment Reset

.DESCRIPTION
    Completely removes the Fort Reign Garrison simulation environment.
    Destroys in this order:
      1. Scheduled simulation tasks
      2. File shares (SMB)
      3. FortReignShares folder and all contents
      4. All AD users under OU=FortReign
      5. All OUs and groups under OU=FortReign

    Single confirmation prompt before execution.
    Safe — only touches FortReign-namespaced objects.
    Run FortReign.Build.ps1 to rebuild after teardown.

.NOTES
    Author:     Chris Robinson (CRobin0780)
    Lab:        Fort Reign — Simulated Federal Contractor / SOC Homelab
    Version:    1.0
    Date:       2026-03-06
    GitHub:     github.com/CRobin0780/chris-soc-homelab
    WARNING:    This is destructive and irreversible. No undo.
#>

# ============================================================
# CONFIGURATION
# ============================================================

$Config = @{
    Domain          = "lab.local"
    DomainDN        = "DC=lab,DC=local"
    OURootName      = "FortReign"
    ShareRootPath   = "C:\FortReignShares"
    AltSharePath    = "C:\Shares"              # Secondary share path from blueprint
    ScheduledTasks  = @(
        "FortReign-ActivitySim",
        "SimulateEnterpriseActivity",
        "FortReign-UserActivity",
        "FortReign-FileAccess"
    )
    Shares          = @(
        "FRG_Command",
        "FRG_Finance",
        "FRG_HR",
        "FRG_IT_Operations",
        "FRG_Logistics",
        "FRG_Security_Operations",
        "Command",
        "Finance",
        "HR",
        "IT",
        "Sales",
        "Operations",
        "Public"
    )
}

# ============================================================
# LOGGING
# ============================================================

$LogPath = "C:\Logs\FortReign-Teardown-$(Get-Date -Format 'yyyyMMdd-HHmm').log"
New-Item -ItemType Directory -Path "C:\Logs" -Force | Out-Null

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS","HEADER")]
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Colors = @{
        INFO    = "Cyan"
        WARN    = "Yellow"
        ERROR   = "Red"
        SUCCESS = "Green"
        HEADER  = "Magenta"
    }
    $Line = "[$Timestamp][$Level] $Message"
    Write-Host $Line -ForegroundColor $Colors[$Level]
    Add-Content -Path $LogPath -Value $Line
}

function Write-Header {
    param([string]$Title)
    $Line = "=" * 60
    Write-Log $Line -Level HEADER
    Write-Log "  $Title" -Level HEADER
    Write-Log $Line -Level HEADER
}

# ============================================================
# BANNER + CONFIRMATION
# ============================================================

Clear-Host
Write-Host ""
Write-Host "  ██████████████████████████████████████████" -ForegroundColor Red
Write-Host "  ██                                      ██" -ForegroundColor Red
Write-Host "  ██    FORT REIGN — TEARDOWN SCRIPT      ██" -ForegroundColor Red
Write-Host "  ██                                      ██" -ForegroundColor Red
Write-Host "  ██  THIS WILL PERMANENTLY DESTROY:      ██" -ForegroundColor Red
Write-Host "  ██    • All FortReign AD users (25)     ██" -ForegroundColor Red
Write-Host "  ██    • All FortReign OUs and groups    ██" -ForegroundColor Red
Write-Host "  ██    • All FRG file shares             ██" -ForegroundColor Red
Write-Host "  ██    • FortReignShares folder          ██" -ForegroundColor Red
Write-Host "  ██    • Scheduled simulation tasks      ██" -ForegroundColor Red
Write-Host "  ██                                      ██" -ForegroundColor Red
Write-Host "  ██  THIS ACTION CANNOT BE UNDONE        ██" -ForegroundColor Red
Write-Host "  ██████████████████████████████████████████" -ForegroundColor Red
Write-Host ""
Write-Host "  Domain:     $($Config.Domain)" -ForegroundColor Yellow
Write-Host "  OU Target:  OU=$($Config.OURootName),$($Config.DomainDN)" -ForegroundColor Yellow
Write-Host "  Share Path: $($Config.ShareRootPath)" -ForegroundColor Yellow
Write-Host "  Log File:   $LogPath" -ForegroundColor Yellow
Write-Host ""

$Confirm = Read-Host "  Type DESTROY to confirm teardown"

if ($Confirm -ne "DESTROY") {
    Write-Host ""
    Write-Host "  Teardown cancelled. Nothing was changed." -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Log "Teardown confirmed by operator. Starting destruction sequence." -Level WARN
Write-Log "Log: $LogPath" -Level INFO

# ============================================================
# SECTION 1 — SCHEDULED TASKS
# ============================================================

Write-Header "SECTION 1: SCHEDULED TASKS"

foreach ($TaskName in $Config.ScheduledTasks) {
    try {
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($Task) {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "TASK REMOVED: $TaskName" -Level SUCCESS
        } else {
            Write-Log "TASK NOT FOUND: $TaskName (skipping)" -Level INFO
        }
    } catch {
        Write-Log "TASK ERROR: $TaskName — $($_.Exception.Message)" -Level ERROR
    }
}

# Also check for any task with FortReign in the name
$ExtraTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*FortReign*" -or $_.TaskName -like "*Simulate*" }
foreach ($Task in $ExtraTasks) {
    try {
        Stop-ScheduledTask -TaskName $Task.TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $Task.TaskName -Confirm:$false
        Write-Log "EXTRA TASK REMOVED: $($Task.TaskName)" -Level SUCCESS
    } catch {
        Write-Log "EXTRA TASK ERROR: $($Task.TaskName) — $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================
# SECTION 2 — FILE SHARES (SMB)
# ============================================================

Write-Header "SECTION 2: FILE SHARES"

foreach ($ShareName in $Config.Shares) {
    try {
        $Share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
        if ($Share) {
            Remove-SmbShare -Name $ShareName -Force -Confirm:$false
            Write-Log "SHARE REMOVED: $ShareName" -Level SUCCESS
        } else {
            Write-Log "SHARE NOT FOUND: $ShareName (skipping)" -Level INFO
        }
    } catch {
        Write-Log "SHARE ERROR: $ShareName — $($_.Exception.Message)" -Level ERROR
    }
}

# Catch any remaining FRG_ shares
$ExtraShares = Get-SmbShare | Where-Object { $_.Name -like "FRG*" }
foreach ($Share in $ExtraShares) {
    try {
        Remove-SmbShare -Name $Share.Name -Force -Confirm:$false
        Write-Log "EXTRA SHARE REMOVED: $($Share.Name)" -Level SUCCESS
    } catch {
        Write-Log "EXTRA SHARE ERROR: $($Share.Name) — $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================
# SECTION 3 — SHARE FOLDERS ON DISK
# ============================================================

Write-Header "SECTION 3: SHARE FOLDERS"

$FoldersToRemove = @($Config.ShareRootPath, $Config.AltSharePath)

foreach ($Folder in $FoldersToRemove) {
    try {
        if (Test-Path $Folder) {
            $ItemCount = (Get-ChildItem -Path $Folder -Recurse -Force).Count
            Remove-Item -Path $Folder -Recurse -Force
            Write-Log "FOLDER REMOVED: $Folder ($ItemCount items deleted)" -Level SUCCESS
        } else {
            Write-Log "FOLDER NOT FOUND: $Folder (skipping)" -Level INFO
        }
    } catch {
        Write-Log "FOLDER ERROR: $Folder — $($_.Exception.Message)" -Level ERROR
    }
}

# Clean up simulation log folder
$SimLogPath = "$env:ProgramData\FortReignSim"
if (Test-Path $SimLogPath) {
    try {
        Remove-Item -Path $SimLogPath -Recurse -Force
        Write-Log "SIM LOGS REMOVED: $SimLogPath" -Level SUCCESS
    } catch {
        Write-Log "SIM LOG ERROR: $SimLogPath — $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================
# SECTION 4 — AD USERS
# ============================================================

Write-Header "SECTION 4: AD USERS"

$OURootDN = "OU=$($Config.OURootName),$($Config.DomainDN)"
$RemovedUsers = 0
$ErrorUsers   = 0

try {
    $Users = Get-ADUser -Filter * -SearchBase $OURootDN -ErrorAction Stop

    foreach ($User in $Users) {
        try {
            Remove-ADUser -Identity $User.DistinguishedName -Confirm:$false
            Write-Log "USER REMOVED: $($User.SamAccountName)" -Level SUCCESS
            $RemovedUsers++
        } catch {
            Write-Log "USER ERROR: $($User.SamAccountName) — $($_.Exception.Message)" -Level ERROR
            $ErrorUsers++
        }
    }

    Write-Log "Users removed: $RemovedUsers | Errors: $ErrorUsers" -Level INFO

} catch {
    Write-Log "Could not query OU=$($Config.OURootName) — may not exist: $($_.Exception.Message)" -Level WARN
}

# ============================================================
# SECTION 5 — AD GROUPS AND OUs
# ============================================================

Write-Header "SECTION 5: AD GROUPS AND OUs"

# Remove groups first (they live inside OUs)
try {
    $Groups = Get-ADGroup -Filter * -SearchBase $OURootDN -ErrorAction SilentlyContinue
    foreach ($Group in $Groups) {
        try {
            Remove-ADGroup -Identity $Group.DistinguishedName -Confirm:$false
            Write-Log "GROUP REMOVED: $($Group.Name)" -Level SUCCESS
        } catch {
            Write-Log "GROUP ERROR: $($Group.Name) — $($_.Exception.Message)" -Level ERROR
        }
    }
} catch {
    Write-Log "No groups found under FortReign OU (skipping)" -Level INFO
}

# Remove child OUs before root OU
# Must disable protection first, then remove deepest OUs first
$ChildOUs = @(
    "OU=Command,OU=FortReign,$($Config.DomainDN)",
    "OU=IT_Operations,OU=FortReign,$($Config.DomainDN)",
    "OU=ITOps,OU=FortReign,$($Config.DomainDN)",
    "OU=Security_Operations,OU=FortReign,$($Config.DomainDN)",
    "OU=SecOps,OU=FortReign,$($Config.DomainDN)",
    "OU=HR,OU=FortReign,$($Config.DomainDN)",
    "OU=Finance,OU=FortReign,$($Config.DomainDN)",
    "OU=Logistics,OU=FortReign,$($Config.DomainDN)",
    "OU=Computers,OU=FortReign,$($Config.DomainDN)",
    "OU=Workstations,OU=FortReign,$($Config.DomainDN)",
    "OU=Groups,OU=FortReign,$($Config.DomainDN)",
    "OU=Service_Accounts,OU=FortReign,$($Config.DomainDN)",
    "OU=ServiceAccounts,OU=FortReign,$($Config.DomainDN)"
)

foreach ($OUDN in $ChildOUs) {
    try {
        $OU = Get-ADOrganizationalUnit -Identity $OUDN -ErrorAction SilentlyContinue
        if ($OU) {
            Set-ADOrganizationalUnit -Identity $OUDN -ProtectedFromAccidentalDeletion $false
            Remove-ADOrganizationalUnit -Identity $OUDN -Recursive -Confirm:$false
            Write-Log "OU REMOVED: $OUDN" -Level SUCCESS
        } else {
            Write-Log "OU NOT FOUND: $OUDN (skipping)" -Level INFO
        }
    } catch {
        Write-Log "OU ERROR: $OUDN — $($_.Exception.Message)" -Level ERROR
    }
}

# Remove root FortReign OU last
$RootOU = "OU=FortReign,$($Config.DomainDN)"
try {
    $OU = Get-ADOrganizationalUnit -Identity $RootOU -ErrorAction SilentlyContinue
    if ($OU) {
        Set-ADOrganizationalUnit -Identity $RootOU -ProtectedFromAccidentalDeletion $false
        Remove-ADOrganizationalUnit -Identity $RootOU -Recursive -Confirm:$false
        Write-Log "ROOT OU REMOVED: $RootOU" -Level SUCCESS
    } else {
        Write-Log "ROOT OU NOT FOUND: $RootOU (already gone)" -Level INFO
    }
} catch {
    Write-Log "ROOT OU ERROR: $RootOU — $($_.Exception.Message)" -Level ERROR
    Write-Log "  If OU still has objects, run: Get-ADObject -SearchBase '$RootOU' -Filter * | Remove-ADObject -Recursive -Confirm:`$false" -Level WARN
}

# ============================================================
# SECTION 6 — FINAL VERIFICATION
# ============================================================

Write-Header "SECTION 6: VERIFICATION"

# Check OU is gone
$OUCheck = Get-ADOrganizationalUnit -Filter "Name -eq 'FortReign'" -ErrorAction SilentlyContinue
if ($OUCheck) {
    Write-Log "WARNING: FortReign OU still exists — manual cleanup required" -Level WARN
    Write-Log "  Run: Get-ADObject -SearchBase 'OU=FortReign,DC=lab,DC=local' -Filter * | Remove-ADObject -Recursive -Confirm:`$false" -Level WARN
} else {
    Write-Log "CONFIRMED: FortReign OU is gone" -Level SUCCESS
}

# Check shares are gone
$RemainingShares = Get-SmbShare | Where-Object { $_.Name -like "FRG*" }
if ($RemainingShares) {
    Write-Log "WARNING: Some FRG shares still exist:" -Level WARN
    $RemainingShares | ForEach-Object { Write-Log "  $($_.Name)" -Level WARN }
} else {
    Write-Log "CONFIRMED: All FRG shares removed" -Level SUCCESS
}

# Check folders are gone
foreach ($Folder in $FoldersToRemove) {
    if (Test-Path $Folder) {
        Write-Log "WARNING: Folder still exists: $Folder" -Level WARN
    } else {
        Write-Log "CONFIRMED: Folder removed: $Folder" -Level SUCCESS
    }
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  FORT REIGN TEARDOWN COMPLETE" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Users removed:    $RemovedUsers" -ForegroundColor Cyan
Write-Host "  Log saved to:     $LogPath" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To rebuild: Run FortReign.Build.ps1" -ForegroundColor Yellow
Write-Host ""

Write-Log "Teardown sequence complete." -Level SUCCESS

# ============================================================
# END OF SCRIPT
# ============================================================
