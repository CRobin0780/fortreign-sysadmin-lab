# =========================================
# File: .\FortReign\FortReign.Build.ps1
# =========================================
<#
.SYNOPSIS
Builds the Fort Reign Garrison IT Operations lab environment:
- AD OU structure, groups, and user accounts (~30)
- Department SMB shares with NTFS + share permissions
- Seeds realistic documents/data into shares
- Installs scheduled tasks for business-hours activity simulation

.REQUIREMENTS
- Run as Domain Admin (lab) or with rights to create AD objects + SMB shares + scheduled tasks
- RSAT ActiveDirectory module on the machine running this script
- File server access to create directories + shares (can be localhost in homelab)

.NOTES
- This is lab/simulation code. Review before running in non-lab environments.
- Idempotent: safe to re-run; will skip existing objects when possible.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string] $CompanyShort = "FortReign",

  [Parameter(Mandatory = $false)]
  [string] $BaseOUName = "FortReign",

  [Parameter(Mandatory = $false)]
  [string] $SharesRoot = "D:\FortReignShares",

  [Parameter(Mandatory = $false)]
  [string] $FileServer = $env:COMPUTERNAME,

  [Parameter(Mandatory = $false)]
  [string] $DefaultUserPassword = "P@ssw0rd!ChangeMe",

  [Parameter(Mandatory = $false)]
  [ValidateRange(0,23)]
  [int] $BusinessStartHour = 8,

  [Parameter(Mandatory = $false)]
  [ValidateRange(0,23)]
  [int] $BusinessEndHour = 17,

  [Parameter(Mandatory = $false)]
  [ValidateSet("Mon","Tue","Wed","Thu","Fri","Sat","Sun")]
  [string[]] $BusinessDays = @("Mon","Tue","Wed","Thu","Fri"),

  [Parameter(Mandatory = $false)]
  [switch] $InstallActivitySimulation = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------
# Helpers
# ---------------------------
function Write-Step {
  param([string]$Message)
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

function Assert-Module {
  param([string]$Name)
  if (-not (Get-Module -ListAvailable -Name $Name)) {
    throw "Required module '$Name' not found. Install RSAT / module and retry."
  }
  Import-Module $Name -ErrorAction Stop
}

function Get-DomainDN {
  try {
    $domain = Get-ADDomain
    return $domain.DistinguishedName
  } catch {
    throw "Failed to query domain. Are you joined to a domain and running with AD rights? $($_.Exception.Message)"
  }
}

function Ensure-ADOU {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [string]$Path
  )
  $dn = "OU=$Name,$Path"
  $existing = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue
  if (-not $existing) {
    Write-Step "Creating OU: $dn"
    New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false | Out-Null
  } else {
    Write-Step "OU exists: $dn"
  }
  return $dn
}

function Ensure-ADGroup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter(Mandatory)]
    [string]$Path,
    [Parameter(Mandatory)]
    [ValidateSet("Global","Universal","DomainLocal")]
    [string]$Scope = "Global",
    [Parameter(Mandatory)]
    [ValidateSet("Security","Distribution")]
    [string]$Category = "Security",
    [string]$Description = ""
  )
  $existing = Get-ADGroup -Filter "SamAccountName -eq '$Name'" -ErrorAction SilentlyContinue
  if (-not $existing) {
    Write-Step "Creating group: $Name"
    New-ADGroup -Name $Name -SamAccountName $Name -GroupScope $Scope -GroupCategory $Category -Path $Path -Description $Description | Out-Null
  } else {
    Write-Step "Group exists: $Name"
  }
  return (Get-ADGroup -Identity $Name)
}

function Ensure-ADUser {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$User,
    [Parameter(Mandatory)]
    [string]$OUdn,
    [Parameter(Mandatory)]
    [securestring]$PasswordSecure
  )

  $sam = $User.SamAccountName
  $existing = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
  if (-not $existing) {
    Write-Step "Creating user: $sam ($($User.DisplayName))"
    New-ADUser `
      -Name $User.DisplayName `
      -DisplayName $User.DisplayName `
      -GivenName $User.GivenName `
      -Surname $User.Surname `
      -SamAccountName $sam `
      -UserPrincipalName ($sam + "@" + (Get-ADDomain).DnsRoot) `
      -Path $OUdn `
      -AccountPassword $PasswordSecure `
      -Enabled $true `
      -ChangePasswordAtLogon $true `
      -Department $User.Department `
      -Title $User.Title `
      -Company $CompanyShort `
      -Office $User.Office `
      -EmailAddress $User.Email `
      -Description $User.Description | Out-Null
  } else {
    Write-Step "User exists: $sam"
  }
  return (Get-ADUser -Identity $sam -Properties Department,Title,Mail)
}

function Ensure-GroupMembers {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Group,
    [Parameter(Mandatory)]
    [string[]]$MembersSam
  )
  $grp = Get-ADGroup -Identity $Group
  $current = (Get-ADGroupMember -Identity $grp -Recursive | Where-Object { $_.objectClass -eq "user" } | Select-Object -ExpandProperty SamAccountName)
  $toAdd = $MembersSam | Where-Object { $_ -and ($_ -notin $current) } | Sort-Object -Unique
  if ($toAdd.Count -gt 0) {
    Write-Step "Adding members to $Group: $($toAdd -join ', ')"
    Add-ADGroupMember -Identity $Group -Members $toAdd | Out-Null
  } else {
    Write-Step "No membership changes needed for $Group"
  }
}

function Ensure-Directory {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Step "Creating directory: $Path"
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Ensure-SmbShareSafe {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Description
  )
  $existing = Get-SmbShare -Name $Name -ErrorAction SilentlyContinue
  if (-not $existing) {
    Write-Step "Creating SMB share: $Name -> $Path"
    New-SmbShare -Name $Name -Path $Path -Description $Description -FullAccess "BUILTIN\Administrators" | Out-Null
  } else {
    Write-Step "SMB share exists: $Name"
  }
}

function Set-SharePermissions {
  <#
  WHY: Share permissions are a second layer; we set them to match our NTFS intent.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ShareName,
    [Parameter(Mandatory)][string]$DeptRWGroup,
    [Parameter(Mandatory)][string]$DeptROGroup
  )

  # Remove Everyone if present (lab hardening)
  $access = Get-SmbShareAccess -Name $ShareName
  foreach ($entry in $access) {
    if ($entry.AccountName -match "^Everyone$") {
      Write-Step "Removing share access Everyone from $ShareName"
      Revoke-SmbShareAccess -Name $ShareName -AccountName "Everyone" -Force | Out-Null
    }
  }

  # Ensure dept permissions
  $needed = @(
    @{ Account = $DeptRWGroup; Right = "Change" },
    @{ Account = $DeptROGroup; Right = "Read" }
  )

  foreach ($n in $needed) {
    $exists = (Get-SmbShareAccess -Name $ShareName | Where-Object { $_.AccountName -ieq $n.Account -and $_.AccessRight -eq $n.Right })
    if (-not $exists) {
      Write-Step "Granting share $($n.Right) to $($n.Account) on $ShareName"
      Grant-SmbShareAccess -Name $ShareName -AccountName $n.Account -AccessRight $n.Right -Force | Out-Null
    }
  }
}

function Set-NTFSPermissions {
  <#
  WHY: NTFS is authoritative in most environments. We set explicit rules:
  - Admins Full
  - Dept RW Modify
  - Dept RO ReadAndExecute
  - Disable inheritance to avoid accidental broad access
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$DeptRWGroup,
    [Parameter(Mandatory)][string]$DeptROGroup
  )

  $acl = Get-Acl -Path $Path

  if (-not $acl.AreAccessRulesProtected) {
    Write-Step "Disabling inheritance (and converting inherited rules) for: $Path"
    $acl.SetAccessRuleProtection($true, $true)
  }

  $rules = @(
    New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow"),
    New-Object System.Security.AccessControl.FileSystemAccessRule($DeptRWGroup,"Modify","ContainerInherit,ObjectInherit","None","Allow"),
    New-Object System.Security.AccessControl.FileSystemAccessRule($DeptROGroup,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
  )

  # Remove any overly broad rules (Everyone, Authenticated Users) to keep lab tidy
  $broad = @("Everyone","NT AUTHORITY\Authenticated Users")
  foreach ($r in $acl.Access) {
    if ($broad -contains $r.IdentityReference.Value) {
      $acl.RemoveAccessRule($r) | Out-Null
    }
  }

  foreach ($rule in $rules) {
    $acl.SetAccessRule($rule)
  }

  Set-Acl -Path $Path -AclObject $acl
}

function New-RandomId {
  param([int]$Len = 8)
  $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  -join (1..$Len | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}

function Write-TextFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Content
  )
  $dir = Split-Path -Parent $Path
  Ensure-Directory -Path $dir
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Seed-DepartmentData {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Dept,
    [Parameter(Mandatory)][string]$DeptPath
  )

  $today = Get-Date -Format "yyyy-MM-dd"
  $caseId = "FRG-" + (Get-Date -Format "yyyy") + "-" + (New-RandomId -Len 6)

  switch ($Dept) {
    "Command" {
      Write-TextFile -Path (Join-Path $DeptPath "Policies\Command-Intent-$today.txt") -Content @"
FORT REIGN GARRISON
Commander's Intent
Date: $today

1. Maintain operational readiness and secure IT posture.
2. Enforce least privilege access and auditable workflows.
3. Prioritize incident response maturity and telemetry fidelity.

Ref: $caseId
"@
      Write-TextFile -Path (Join-Path $DeptPath "Briefings\Ops-Brief-$today.txt") -Content @"
Operations Brief - $today
- Status: GREEN
- Top Risks: Credential reuse, shadow IT, stale accounts
- Action: Quarterly access review; patch cycle adherence

Brief ID: $caseId
"@
    }

    "ITOps" {
      $csv = @()
      1..20 | ForEach-Object {
        $csv += [pscustomobject]@{
          TicketId    = "IT-" + (New-RandomId -Len 7)
          Opened      = (Get-Date).AddDays(-1 * (Get-Random -Minimum 0 -Maximum 30)).ToString("yyyy-MM-dd")
          Category    = (Get-Random @("Endpoint","Network","Accounts","Email","Backup"))
          Priority    = (Get-Random @("P1","P2","P3","P4"))
          Status      = (Get-Random @("Open","In Progress","Resolved"))
          Summary     = (Get-Random @("Password reset request","Printer queue jam","VPN connectivity","Patch compliance exception","Disk space alert"))
        }
      }
      Ensure-Directory -Path (Join-Path $DeptPath "Tickets")
      $csv | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $DeptPath "Tickets\ITOps-Ticket-Backlog.csv")

      Write-TextFile -Path (Join-Path $DeptPath "Runbooks\Standard-Change-Procedure.txt") -Content @"
IT Ops Runbook - Standard Change Procedure
- Pre-check: backups verified, maintenance window approved
- Implement: change steps recorded in ticket
- Validate: service health + rollback readiness
- Closeout: evidence attached, stakeholder notified
"@
    }

    "SecOps" {
      Ensure-Directory -Path (Join-Path $DeptPath "Detections")
      $detections = @()
      1..25 | ForEach-Object {
        $detections += [pscustomobject]@{
          DetectionId = "DET-" + (New-RandomId -Len 8)
          Created     = (Get-Date).AddDays(-1 * (Get-Random -Minimum 0 -Maximum 60)).ToString("yyyy-MM-dd")
          Severity    = (Get-Random @("Low","Medium","High"))
          Technique   = (Get-Random @("Credential Access","Discovery","Lateral Movement","Defense Evasion"))
          RuleName    = (Get-Random @("Suspicious PowerShell","Impossible Travel","New Admin Group Member","Multiple Failed Logons"))
          Enabled     = (Get-Random @($true,$true,$true,$false))
        }
      }
      $detections | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $DeptPath "Detections\SIEM-Detections.csv")

      Write-TextFile -Path (Join-Path $DeptPath "IR\Playbook-Phishing.txt") -Content @"
Incident Response Playbook: Phishing
1) Triage report, identify impacted users
2) Reset credentials, revoke sessions/tokens if applicable
3) Search for similar messages and IOCs
4) Contain: block sender/domain, remove emails
5) Recover: validate endpoints, review MFA status
6) Lessons learned: update training + controls
"@
    }

    "HR" {
      Ensure-Directory -Path (Join-Path $DeptPath "Personnel")
      $people = @()
      1..18 | ForEach-Object {
        $people += [pscustomobject]@{
          EmployeeId  = "FR-" + (Get-Random -Minimum 10000 -Maximum 99999)
          StartDate   = (Get-Date).AddDays(-1*(Get-Random -Minimum 30 -Maximum 900)).ToString("yyyy-MM-dd")
          Status      = (Get-Random @("Active","Active","Active","On Leave"))
          Clearance   = (Get-Random @("None","Public Trust","Secret","Top Secret"))
          TrainingDue = (Get-Date).AddDays((Get-Random -Minimum 7 -Maximum 120)).ToString("yyyy-MM-dd")
        }
      }
      $people | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $DeptPath "Personnel\HR-Training-Tracker.csv")

      Write-TextFile -Path (Join-Path $DeptPath "Policies\Acceptable-Use.txt") -Content @"
Acceptable Use Policy (AUP)
- Use corporate systems for authorized purposes only
- No credential sharing
- Report suspected security incidents immediately
- Follow data handling and retention guidelines
"@
    }

    "Finance" {
      Ensure-Directory -Path (Join-Path $DeptPath "Budget")
      $lines = @()
      1..24 | ForEach-Object {
        $lines += [pscustomobject]@{
          CostCenter = (Get-Random @("FIN-OPS","FIN-PROC","IT-OPS","SEC-OPS","LOG-OPS"))
          Month      = (Get-Random @("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"))
          Vendor     = (Get-Random @("Contoso Cloud","Northwind Supplies","Fabrikam Telecom","Litware Licensing"))
          AmountUSD  = [math]::Round((Get-Random -Minimum 1200 -Maximum 45000) + (Get-Random), 2)
          ApprovedBy = (Get-Random @("CFO","Deputy CFO","Controller"))
        }
      }
      $lines | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $DeptPath "Budget\FY-Budget-Lines.csv")

      Write-TextFile -Path (Join-Path $DeptPath "Procedures\Invoice-Approval.txt") -Content @"
Invoice Approval Procedure
- Validate PO + receiving
- Match line items
- Approve thresholds: <=5k Controller, <=25k CFO, >25k Command
"@
    }

    "Logistics" {
      Ensure-Directory -Path (Join-Path $DeptPath "Inventory")
      $assets = @()
      1..30 | ForEach-Object {
        $assets += [pscustomobject]@{
          AssetTag    = "FRG-" + (New-RandomId -Len 7)
          Type        = (Get-Random @("Laptop","Desktop","Switch","Firewall","AP","Printer"))
          Model       = (Get-Random @("Model-A","Model-B","Model-C","Model-D"))
          Location    = (Get-Random @("HQ-1F","HQ-2F","HQ-DC","Warehouse","Remote"))
          Status      = (Get-Random @("In Service","In Service","Spare","Repair"))
          LastAudit   = (Get-Date).AddDays(-1*(Get-Random -Minimum 1 -Maximum 365)).ToString("yyyy-MM-dd")
        }
      }
      $assets | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $DeptPath "Inventory\Asset-Inventory.csv")

      Write-TextFile -Path (Join-Path $DeptPath "Shipping\Outbound-Checklist.txt") -Content @"
Outbound Shipment Checklist
- Asset tag verified
- Device encrypted
- User assignment recorded
- Shipping label generated
- Chain-of-custody logged
"@
    }
  }
}

function Install-ActivitySim {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$SimRoot,
    [Parameter(Mandatory)][string]$SharesRoot,
    [Parameter(Mandatory)][int]$BusinessStartHour,
    [Parameter(Mandatory)][int]$BusinessEndHour,
    [Parameter(Mandatory)][string[]]$BusinessDays
  )

  Ensure-Directory -Path $SimRoot
  $simScript = Join-Path $SimRoot "FortReign.ActivitySim.ps1"

  Write-Step "Writing activity simulation script: $simScript"

  $daysMap = @{
    Mon = 1; Tue = 2; Wed = 3; Thu = 4; Fri = 5; Sat = 6; Sun = 0
  }
  $daysNums = ($BusinessDays | ForEach-Object { $daysMap[$_] }) -join ","

  @"
<#
.SYNOPSIS
Fort Reign Activity Simulation

.DESCRIPTION
Generates baseline "normal" business activity:
- Random read/write/touch on departmental files
- Creates small log artifacts
- Intended for SIEM tuning and telemetry generation

.NOTES
- Runs under the local scheduled task account context.
- For stronger identity telemetry, create tasks per-user (lab optional).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=\$false)]
  [string] \$SharesRoot = "$SharesRoot",

  [Parameter(Mandatory=\$false)]
  [int] \$BusinessStartHour = $BusinessStartHour,

  [Parameter(Mandatory=\$false)]
  [int] \$BusinessEndHour = $BusinessEndHour
)

Set-StrictMode -Version Latest
\$ErrorActionPreference = "Stop"

function In-BusinessHours {
  \$now = Get-Date
  if (\$now.Hour -lt \$BusinessStartHour) { return \$false }
  if (\$now.Hour -ge \$BusinessEndHour) { return \$false }
  return \$true
}

function Pick-RandomFile {
  param([string]\$Root)
  \$files = Get-ChildItem -Path \$Root -File -Recurse -ErrorAction SilentlyContinue
  if (-not \$files -or \$files.Count -eq 0) { return \$null }
  return \$files | Get-Random
}

function Touch-File {
  param([string]\$Path)
  if (-not (Test-Path -LiteralPath \$Path)) { return }
  \$content = Get-Content -Path \$Path -ErrorAction SilentlyContinue
  # WHY: A small append creates write telemetry without generating huge artifacts.
  Add-Content -Path \$Path -Value ("`n# sim-touch " + (Get-Date -Format o)) -ErrorAction SilentlyContinue
}

function Read-File {
  param([string]\$Path)
  if (-not (Test-Path -LiteralPath \$Path)) { return }
  Get-Content -Path \$Path -TotalCount 50 -ErrorAction SilentlyContinue | Out-Null
}

function Write-LocalSimLog {
  param([string]\$Message)
  \$logDir = Join-Path \$env:ProgramData "FortReignSim"
  if (-not (Test-Path -LiteralPath \$logDir)) { New-Item -ItemType Directory -Path \$logDir -Force | Out-Null }
  \$logPath = Join-Path \$logDir "activity.log"
  Add-Content -Path \$logPath -Value ("[" + (Get-Date -Format o) + "] " + \$Message)
}

if (-not (In-BusinessHours)) {
  Write-LocalSimLog "Outside business hours: idle tick"
  exit 0
}

\$deptDirs = @("Command","ITOps","SecOps","HR","Finance","Logistics") | ForEach-Object { Join-Path \$SharesRoot \$_ }
\$deptDirs = \$deptDirs | Where-Object { Test-Path -LiteralPath \$_ }

if (-not \$deptDirs -or \$deptDirs.Count -eq 0) {
  Write-LocalSimLog "No department dirs found under \$SharesRoot"
  exit 0
}

# Weighted behavior: more reads than writes; occasional writes.
\$action = Get-Random -InputObject @("Read","Read","Read","Touch","Read","Touch","Read","Read")
\$dept = \$deptDirs | Get-Random
\$file = Pick-RandomFile -Root \$dept

if (-not \$file) {
  Write-LocalSimLog "No files found under \$dept"
  exit 0
}

switch (\$action) {
  "Read"  { Read-File -Path \$file.FullName;  Write-LocalSimLog "READ  \$($file.FullName)" }
  "Touch" { Touch-File -Path \$file.FullName; Write-LocalSimLog "WRITE \$($file.FullName)" }
}
"@ | Set-Content -Path $simScript -Encoding UTF8

  # Scheduled Task: weekdays every 15 minutes
  $taskName = "FortReign-ActivitySim"
  Write-Step "Installing scheduled task: $taskName"

  $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null
  }

  $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$simScript`""
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $BusinessDays -At ([datetime]"08:00")
  $trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Hours 12)).Repetition

  $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
}

# ---------------------------
# Main
# ---------------------------
Assert-Module -Name "ActiveDirectory"

Write-Step "Fort Reign build starting..."
$domainDn = Get-DomainDN
Write-Step "Domain DN: $domainDn"

$baseOUdn = Ensure-ADOU -Name $BaseOUName -Path $domainDn

$departments = @(
  @{ Name = "Command";   OU = $null },
  @{ Name = "ITOps";     OU = $null },
  @{ Name = "SecOps";    OU = $null },
  @{ Name = "HR";        OU = $null },
  @{ Name = "Finance";   OU = $null },
  @{ Name = "Logistics"; OU = $null }
)

foreach ($d in $departments) {
  $d.OU = Ensure-ADOU -Name $d.Name -Path $baseOUdn
}

# Groups
Write-Step "Creating department groups..."
$allEmployeesGroup = Ensure-ADGroup -Name "FRG_AllEmployees" -Path $baseOUdn -Description "All Fort Reign Garrison employees"
$deptGroups = @{}

foreach ($d in $departments) {
  $rw = "FRG_{0}_RW" -f $d.Name
  $ro = "FRG_{0}_RO" -f $d.Name
  Ensure-ADGroup -Name $rw -Path $baseOUdn -Description "$($d.Name) Read/Write access"
  Ensure-ADGroup -Name $ro -Path $baseOUdn -Description "$($d.Name) Read-only access"
  $deptGroups[$d.Name] = @{ RW = $rw; RO = $ro }
}

# Users (realistic roster)
Write-Step "Generating Fort Reign user roster..."
$roster = @(
  # Command
  [pscustomobject]@{ GivenName="Evelyn"; Surname="Hale";   SamAccountName="ehale";   Department="Command"; Title="Garrison Commander"; Office="HQ"; Email="evelyn.hale@fortreign.local"; Description="Command - Approval authority"; Groups=@("FRG_Command_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Marcus"; Surname="Keene";  SamAccountName="mkeene";  Department="Command"; Title="Deputy Commander";  Office="HQ"; Email="marcus.keene@fortreign.local"; Description="Command - Ops oversight";       Groups=@("FRG_Command_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Noah";   Surname="Vance";  SamAccountName="nvance";  Department="Command"; Title="Executive Assistant"; Office="HQ"; Email="noah.vance@fortreign.local"; Description="Command - Admin support";      Groups=@("FRG_Command_RO","FRG_AllEmployees") },

  # ITOps
  [pscustomobject]@{ GivenName="Priya";  Surname="Nair";   SamAccountName="pnair";   Department="ITOps";   Title="IT Ops Manager";     Office="IT"; Email="priya.nair@fortreign.local"; Description="IT Ops lead";                 Groups=@("FRG_ITOps_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Caleb";  Surname="Ortiz";  SamAccountName="cortiz";  Department="ITOps";   Title="Systems Engineer";    Office="IT"; Email="caleb.ortiz@fortreign.local"; Description="Windows/AD";                  Groups=@("FRG_ITOps_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Jenna";  Surname="Rios";   SamAccountName="jrios";   Department="ITOps";   Title="Network Engineer";    Office="IT"; Email="jenna.rios@fortreign.local"; Description="Switching/Routing";           Groups=@("FRG_ITOps_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Dylan";  Surname="Morris"; SamAccountName="dmorris"; Department="ITOps";   Title="Helpdesk Tech";       Office="IT"; Email="dylan.morris@fortreign.local"; Description="Tier 1 support";              Groups=@("FRG_ITOps_RO","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Sofia";  Surname="Park";   SamAccountName="spark";   Department="ITOps";   Title="Helpdesk Tech";       Office="IT"; Email="sofia.park@fortreign.local"; Description="Tier 1 support";              Groups=@("FRG_ITOps_RO","FRG_AllEmployees") },

  # SecOps
  [pscustomobject]@{ GivenName="Omar";   Surname="Bishop"; SamAccountName="obishop"; Department="SecOps";  Title="Security Ops Lead";   Office="SOC"; Email="omar.bishop@fortreign.local"; Description="SOC lead";                    Groups=@("FRG_SecOps_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Mei";    Surname="Chen";   SamAccountName="mchen";   Department="SecOps";  Title="SOC Analyst";         Office="SOC"; Email="mei.chen@fortreign.local"; Description="Monitoring/Triage";           Groups=@("FRG_SecOps_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Grant";  Surname="Sutter"; SamAccountName="gsutter"; Department="SecOps";  Title="Threat Hunter";       Office="SOC"; Email="grant.sutter@fortreign.local"; Description="Proactive hunting";           Groups=@("FRG_SecOps_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Aisha";  Surname="Khan";   SamAccountName="akhan";   Department="SecOps";  Title="GRC Analyst";         Office="SOC"; Email="aisha.khan@fortreign.local"; Description="Policy/Compliance";           Groups=@("FRG_SecOps_RO","FRG_AllEmployees") },

  # HR
  [pscustomobject]@{ GivenName="Lena";   Surname="Rowe";   SamAccountName="lrowe";   Department="HR";     Title="HR Manager";          Office="HR"; Email="lena.rowe@fortreign.local"; Description="HR lead";                     Groups=@("FRG_HR_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Ben";    Surname="Ibrahim";SamAccountName="bibrahim";Department="HR";     Title="HR Specialist";       Office="HR"; Email="ben.ibrahim@fortreign.local"; Description="Onboarding/benefits";         Groups=@("FRG_HR_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Tara";   Surname="Miles";  SamAccountName="tmiles";  Department="HR";     Title="Training Coordinator";Office="HR"; Email="tara.miles@fortreign.local"; Description="Training tracking";           Groups=@("FRG_HR_RO","FRG_AllEmployees") },

  # Finance
  [pscustomobject]@{ GivenName="Victor"; Surname="Lang";   SamAccountName="vlang";   Department="Finance";Title="Chief Financial Officer";Office="FIN";Email="victor.lang@fortreign.local"; Description="Budget authority";            Groups=@("FRG_Finance_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Nina";   Surname="Patel";  SamAccountName="npatel";  Department="Finance";Title="Controller";           Office="FIN";Email="nina.patel@fortreign.local"; Description="Accounting";                  Groups=@("FRG_Finance_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Ethan";  Surname="Wells";  SamAccountName="ewells";  Department="Finance";Title="Procurement Analyst";   Office="FIN";Email="ethan.wells@fortreign.local"; Description="Vendor/PO";                   Groups=@("FRG_Finance_RO","FRG_AllEmployees") },

  # Logistics
  [pscustomobject]@{ GivenName="Rosa";   Surname="Diaz";   SamAccountName="rdiaz";   Department="Logistics";Title="Logistics Manager";   Office="LOG";Email="rosa.diaz@fortreign.local"; Description="Asset logistics";             Groups=@("FRG_Logistics_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Hank";   Surname="Foster"; SamAccountName="hfoster"; Department="Logistics";Title="Inventory Specialist";Office="LOG";Email="hank.foster@fortreign.local"; Description="Asset audits";                Groups=@("FRG_Logistics_RW","FRG_AllEmployees") },
  [pscustomobject]@{ GivenName="Ivy";    Surname="Stone";  SamAccountName="istone";  Department="Logistics";Title="Shipping Clerk";      Office="LOG";Email="ivy.stone@fortreign.local"; Description="Ship/receive";                Groups=@("FRG_Logistics_RO","FRG_AllEmployees") }
)

# Add extra staff to reach ~30
$extra = @(
  @{Dept="ITOps"; First="Mason"; Last="King"; Title="Endpoint Admin"},
  @{Dept="ITOps"; First="Aria"; Last="Ng"; Title="Backup Operator"},
  @{Dept="SecOps"; First="Jules"; Last="Hart"; Title="SOC Analyst"},
  @{Dept="SecOps"; First="Kayla"; Last="Stone"; Title="SOC Analyst"},
  @{Dept="HR"; First="Diego"; Last="Santos"; Title="Recruiter"},
  @{Dept="Finance"; First="Chloe"; Last="Bennett"; Title="AP Specialist"},
  @{Dept="Finance"; First="Isaac"; Last="Reed"; Title="Budget Analyst"},
  @{Dept="Logistics"; First="Mira"; Last="Singh"; Title="Warehouse Tech"},
  @{Dept="Command"; First="Seth"; Last="Porter"; Title="Program Manager"},
  @{Dept="Command"; First="Amara"; Last="Blake"; Title="Operations Coordinator"}
)

foreach ($e in $extra) {
  $sam = ($e.First.Substring(0,1) + $e.Last).ToLower()
  $roster += [pscustomobject]@{
    GivenName = $e.First
    Surname = $e.Last
    SamAccountName = $sam
    Department = $e.Dept
    Title = $e.Title
    Office = "HQ"
    Email = "$($e.First.ToLower()).$($e.Last.ToLower())@fortreign.local"
    Description = "Generated staff"
    Groups = @("FRG_$($e.Dept)_RO","FRG_AllEmployees")
  }
}

# Create users
$passwordSecure = ConvertTo-SecureString $DefaultUserPassword -AsPlainText -Force

$createdUsers = @()
foreach ($u in $roster) {
  $ouDn = ($departments | Where-Object { $_.Name -eq $u.Department }).OU
  $display = "$($u.GivenName) $($u.Surname)"
  $userObj = [pscustomobject]@{
    GivenName = $u.GivenName
    Surname = $u.Surname
    DisplayName = $display
    SamAccountName = $u.SamAccountName
    Department = $u.Department
    Title = $u.Title
    Office = $u.Office
    Email = $u.Email
    Description = $u.Description
  }

  $adUser = Ensure-ADUser -User $userObj -OUdn $ouDn -PasswordSecure $passwordSecure
  $createdUsers += $adUser.SamAccountName
}

# Group membership
Write-Step "Applying group memberships..."
Ensure-GroupMembers -Group "FRG_AllEmployees" -MembersSam $createdUsers

foreach ($u in $roster) {
  foreach ($g in $u.Groups) {
    Ensure-GroupMembers -Group $g -MembersSam @($u.SamAccountName)
  }
}

# Shares
Write-Step "Building department shares..."
Ensure-Directory -Path $SharesRoot

$shareDefs = @(
  @{ Dept="Command";   Share="FRG_Command";   Sub=@("Policies","Briefings","Plans") },
  @{ Dept="ITOps";     Share="FRG_ITOps";     Sub=@("Runbooks","Tickets","Projects","Configs") },
  @{ Dept="SecOps";    Share="FRG_SecOps";    Sub=@("IR","Detections","ThreatIntel","Evidence") },
  @{ Dept="HR";        Share="FRG_HR";        Sub=@("Policies","Personnel","Onboarding") },
  @{ Dept="Finance";   Share="FRG_Finance";   Sub=@("Budget","Procedures","Invoices") },
  @{ Dept="Logistics"; Share="FRG_Logistics"; Sub=@("Inventory","Shipping","Receiving") }
)

foreach ($s in $shareDefs) {
  $deptPath = Join-Path $SharesRoot $s.Dept
  Ensure-Directory -Path $deptPath
  foreach ($sub in $s.Sub) { Ensure-Directory -Path (Join-Path $deptPath $sub) }

  $rw = $deptGroups[$s.Dept].RW
  $ro = $deptGroups[$s.Dept].RO

  # NTFS ACL
  Set-NTFSPermissions -Path $deptPath -DeptRWGroup $rw -DeptROGroup $ro

  # SMB share
  Ensure-SmbShareSafe -Name $s.Share -Path $deptPath -Description "Fort Reign $($s.Dept) Department Share"
  Set-SharePermissions -ShareName $s.Share -DeptRWGroup $rw -DeptROGroup $ro

  # Seed sample data
  Write-Step "Seeding data for $($s.Dept)..."
  Seed-DepartmentData -Dept $s.Dept -DeptPath $deptPath
}

# Activity simulation
if ($InstallActivitySimulation) {
  $simRoot = Join-Path $env:ProgramData "FortReignSim"
  Install-ActivitySim -SimRoot $simRoot -SharesRoot $SharesRoot -BusinessStartHour $BusinessStartHour -BusinessEndHour $BusinessEndHour -BusinessDays $BusinessDays
}

Write-Step "Fort Reign build complete."
Write-Step "Shares root: $SharesRoot"
Write-Step "Example share paths: \\$FileServer\FRG_ITOps , \\$FileServer\FRG_SecOps ..."
Write-Step "Default user password (change at next logon): $DefaultUserPassword"


# =========================================
# File: .\FortReign\FortReign.Teardown.ps1
# =========================================
<#
.SYNOPSIS
Optional teardown: removes Fort Reign shares, scheduled tasks, and AD objects created by FortReign.Build.ps1.

.DESCRIPTION
Use carefully; intended for lab reset.
#>
# NOTE: Put teardown in a separate run context if you want to keep it isolated.
# For safety, it's provided as a stub that lists what it would remove.
# Uncomment destructive operations only when you're sure.

<# 
[CmdletBinding()]
param(
  [string] $BaseOUName = "FortReign",
  [string] $SharesRoot = "D:\FortReignShares"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

Write-Host "Would remove scheduled task: FortReign-ActivitySim"
Write-Host "Would remove SMB shares: FRG_Command, FRG_ITOps, FRG_SecOps, FRG_HR, FRG_Finance, FRG_Logistics"
Write-Host "Would remove directory tree: $SharesRoot"
Write-Host "Would remove OU tree: OU=$BaseOUName,<domainDN>"

# Unregister-ScheduledTask -TaskName "FortReign-ActivitySim" -Confirm:$false
# Get-SmbShare -Name "FRG_*" | Remove-SmbShare -Force
# Remove-Item -Path $SharesRoot -Recurse -Force
# Remove-ADOrganizationalUnit -Identity ("OU=$BaseOUName," + (Get-ADDomain).DistinguishedName) -Recursive -Confirm:$false
#>
