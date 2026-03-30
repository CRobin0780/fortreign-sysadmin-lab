# homelab_dc_audit.ps1
# Windows Server / Domain Controller homelab audit

$ErrorActionPreference = 'SilentlyContinue'

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Output "===== HOMELAB DC AUDIT ====="
Write-Output "Timestamp      : $stamp"
Write-Output ""

########## SYSTEM IDENTITY ##########
Write-Output "===== SYSTEM IDENTITY ====="
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os   = Get-CimInstance Win32_OperatingSystem

Write-Output ("Computer Name  : {0}" -f $cs.Name)
Write-Output ("Domain         : {0}" -f $cs.Domain)
Write-Output ("Part of Domain : {0}" -f $cs.PartOfDomain)
Write-Output ("Domain Role    : {0}" -f $cs.DomainRole)
Write-Output ("Logged-on User : {0}" -f (whoami))
Write-Output ("Manufacturer   : {0}" -f $cs.Manufacturer)
Write-Output ("Model          : {0}" -f $cs.Model)
Write-Output ("Total RAM (GB) : {0:N1}" -f ($cs.TotalPhysicalMemory/1GB))
Write-Output ("OS             : {0}" -f $os.Caption)
Write-Output ("OS Version     : {0}" -f $os.Version)
Write-Output ("Install Date   : {0}" -f ($os.InstallDate))
Write-Output ("BIOS Version   : {0}" -f ($bios.SMBIOSBIOSVersion))
Write-Output ("BIOS Release   : {0}" -f ($bios.ReleaseDate))
Write-Output ""

########## NETWORK CONFIG ##########
Write-Output "===== NETWORK CONFIG ====="
Write-Output "--- IPv4 Addresses ---"
Get-NetIPAddress -AddressFamily IPv4 |
  Sort-Object InterfaceAlias |
  Select-Object InterfaceAlias,IPAddress,PrefixLength,Type |
  Format-Table -AutoSize | Out-String | Write-Output

Write-Output "--- DNS Servers ---"
Get-DnsClientServerAddress -AddressFamily IPv4 |
  Select-Object InterfaceAlias,ServerAddresses |
  Format-Table -AutoSize | Out-String | Write-Output

Write-Output "--- Default Route (0.0.0.0/0) ---"
Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
  Select-Object InterfaceAlias,NextHop,RouteMetric |
  Format-Table -AutoSize | Out-String | Write-Output
Write-Output ""

########## AD DS / DNS ROLES ##########
Write-Output "===== AD DS / DNS ROLES ====="
try {
    Get-WindowsFeature AD-Domain-Services, DNS |
      Select-Object Name, DisplayName, InstallState |
      Format-Table -AutoSize | Out-String | Write-Output
} catch {
    Write-Output "Get-WindowsFeature not available (Server Core or missing modules?)."
}
Write-Output ""

########## DOMAIN / FSMO INFO ##########
Write-Output "===== DOMAIN / FSMO INFO ====="
try {
    $forest = Get-ADForest
    $domain = Get-ADDomain

    Write-Output ("Forest Name    : {0}" -f $forest.Name)
    Write-Output ("Domain Name    : {0}" -f $domain.DNSRoot)
    Write-Output ""
    Write-Output "FSMO Role Holders:"
    Write-Output ("  SchemaMaster        : {0}" -f $forest.SchemaMaster)
    Write-Output ("  DomainNamingMaster  : {0}" -f $forest.DomainNamingMaster)
    Write-Output ("  PDCEmulator         : {0}" -f $domain.PDCEmulator)
    Write-Output ("  RIDMaster           : {0}" -f $domain.RIDMaster)
    Write-Output ("  InfrastructureMaster: {0}" -f $domain.InfrastructureMaster)
} catch {
    Write-Output "AD PowerShell module not available or not a DC."
}
Write-Output ""

########## AD HEALTH (BASIC) ##########
Write-Output "===== AD HEALTH (BASIC REPL SUMMARY) ====="
try {
    Get-ADReplicationPartnerMetadata -Target $env:COMPUTERNAME -Scope Server |
      Select-Object Server, Partner, LastReplicationResult, LastReplicationSuccess |
      Format-Table -AutoSize | Out-String | Write-Output
} catch {
    Write-Output "Replication metadata not available (single DC or AD cmdlets missing)."
}
Write-Output ""

########## LISTENING TCP PORTS ##########
Write-Output "===== LISTENING TCP PORTS ====="
Get-NetTCPConnection -State Listen |
  Select-Object LocalAddress,LocalPort,OwningProcess |
  Sort-Object LocalPort |
  Format-Table -AutoSize | Out-String | Write-Output
Write-Output ""

########## RUNNING SERVICES (TOP 25) ##########
Write-Output "===== RUNNING SERVICES (TOP 25 BY NAME) ====="
Get-Service | Where-Object {$_.Status -eq "Running"} |
  Sort-Object DisplayName |
  Select-Object -First 25 DisplayName, Status, Name |
  Format-Table -AutoSize | Out-String | Write-Output
Write-Output ""

########## INSTALLED ROLES / FEATURES (SUMMARY) ##########
Write-Output "===== INSTALLED ROLES / FEATURES (SUMMARY) ====="
try {
    Get-WindowsFeature | Where-Object {$_.InstallState -eq "Installed"} |
      Select-Object DisplayName, Name |
      Sort-Object DisplayName |
      Format-Table -AutoSize | Out-String | Write-Output
} catch {
    Write-Output "Get-WindowsFeature not available in this environment."
}
Write-Output ""

########## LOGGED-ON SESSIONS ##########
Write-Output "===== LOGGED-ON SESSIONS (QUSER) ====="
try {
    quser | Out-String | Write-Output
} catch {
    Write-Output "quser command not available."
}
Write-Output ""

Write-Output "===== DONE ====="
