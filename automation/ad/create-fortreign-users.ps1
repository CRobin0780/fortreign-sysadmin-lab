# Create-FortReignUsers.ps1
# Run on LAB-DC01 as Domain Admin

$Domain = "DC=lab,DC=local"
$DefaultPassword = ConvertTo-SecureString "FortReign2026!" -AsPlainText -Force

# Command (3 users)
$CommandUsers = @(
    @{First="Evelyn"; Last="Hale"; Sam="ehale"; Title="Garrison Commander"; IsAdmin=$true},
    @{First="Marcus"; Last="Keene"; Sam="mkeene"; Title="Deputy Commander"; IsAdmin=$true},
    @{First="Noah"; Last="Vance"; Sam="nvance"; Title="Executive Assistant"; IsAdmin=$false}
)

foreach ($user in $CommandUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department "Command" `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=Command,OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity "GRP_Command" -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

# IT Operations (5 users)
$ITUsers = @(
    @{First="Priya"; Last="Nair"; Sam="pnair"; Title="IT Ops Manager"; IsAdmin=$true; IsHelpdesk=$false},
    @{First="Caleb"; Last="Ortiz"; Sam="cortiz"; Title="Systems Engineer"; IsAdmin=$true; IsHelpdesk=$false},
    @{First="Jenna"; Last="Rios"; Sam="jrios"; Title="Network Engineer"; IsAdmin=$true; IsHelpdesk=$false},
    @{First="Dylan"; Last="Morris"; Sam="dmorris"; Title="Helpdesk Tech"; IsAdmin=$false; IsHelpdesk=$true},
    @{First="Sofia"; Last="Park"; Sam="spark"; Title="Helpdesk Tech"; IsAdmin=$false; IsHelpdesk=$true}
)

foreach ($user in $ITUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department "IT_Operations" `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=IT_Operations,OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity "GRP_IT_Operations" -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    if ($user.IsHelpdesk) { Add-ADGroupMember -Identity "GRP_Helpdesk" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

# Security Operations (4 users)
$SecOpsUsers = @(
    @{First="Omar"; Last="Bishop"; Sam="obishop"; Title="Security Ops Lead"; IsAdmin=$true},
    @{First="Mei"; Last="Chen"; Sam="mchen"; Title="SOC Analyst"; IsAdmin=$false},
    @{First="Grant"; Last="Sutter"; Sam="gsutter"; Title="Threat Hunter"; IsAdmin=$false},
    @{First="Aisha"; Last="Khan"; Sam="akhan"; Title="GRC Analyst"; IsAdmin=$false}
)

foreach ($user in $SecOpsUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department "Security_Operations" `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=Security_Operations,OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity "GRP_Security_Operations" -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

# HR (3 users)
$HRUsers = @(
    @{First="Lena"; Last="Rowe"; Sam="lrowe"; Title="HR Manager"; IsAdmin=$true},
    @{First="Ben"; Last="Ibrahim"; Sam="bibrahim"; Title="HR Specialist"; IsAdmin=$false},
    @{First="Tara"; Last="Miles"; Sam="tmiles"; Title="Training Coordinator"; IsAdmin=$false}
)

foreach ($user in $HRUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department "HR" `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=HR,OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity "GRP_HR" -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

# Finance (3 users)
$FinanceUsers = @(
    @{First="Victor"; Last="Lang"; Sam="vlang"; Title="CFO"; IsAdmin=$true},
    @{First="Nina"; Last="Patel"; Sam="npatel"; Title="Controller"; IsAdmin=$false},
    @{First="Ethan"; Last="Wells"; Sam="ewells"; Title="Procurement Analyst"; IsAdmin=$false}
)

foreach ($user in $FinanceUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department "Finance" `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=Finance,OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity "GRP_Finance" -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

# Logistics (3 users)
$LogisticsUsers = @(
    @{First="Rosa"; Last="Diaz"; Sam="rdiaz"; Title="Logistics Manager"; IsAdmin=$true},
    @{First="Hank"; Last="Foster"; Sam="hfoster"; Title="Inventory Specialist"; IsAdmin=$false},
    @{First="Ivy"; Last="Stone"; Sam="istone"; Title="Shipping Clerk"; IsAdmin=$false}
)

foreach ($user in $LogisticsUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department "Logistics" `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=Logistics,OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity "GRP_Logistics" -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

# Additional staff (4 users)
$AdditionalUsers = @(
    @{First="Mason"; Last="King"; Sam="mking"; Title="Endpoint Admin"; Dept="IT_Operations"; Group="GRP_IT_Operations"; IsAdmin=$false},
    @{First="Jules"; Last="Hart"; Sam="jhart"; Title="SOC Analyst"; Dept="Security_Operations"; Group="GRP_Security_Operations"; IsAdmin=$false},
    @{First="Diego"; Last="Santos"; Sam="dsantos"; Title="Recruiter"; Dept="HR"; Group="GRP_HR"; IsAdmin=$false},
    @{First="Chloe"; Last="Bennett"; Sam="cbennett"; Title="AP Specialist"; Dept="Finance"; Group="GRP_Finance"; IsAdmin=$false}
)

foreach ($user in $AdditionalUsers) {
    New-ADUser -Name "$($user.First) $($user.Last)" `
               -GivenName $user.First `
               -Surname $user.Last `
               -SamAccountName $user.Sam `
               -UserPrincipalName "$($user.Sam)@lab.local" `
               -Title $user.Title `
               -Department $user.Dept `
               -AccountPassword $DefaultPassword `
               -Enabled $true `
               -Path "OU=$($user.Dept),OU=FortReign,$Domain" `
               -PasswordNeverExpires $true `
               -ChangePasswordAtLogon $false
    
    Add-ADGroupMember -Identity $user.Group -Members $user.Sam
    if ($user.IsAdmin) { Add-ADGroupMember -Identity "GRP_Admins" -Members $user.Sam }
    Write-Host "Created: $($user.Sam) - $($user.Title)" -ForegroundColor Green
}

Write-Host "`n✅ Fort Reign Garrison user structure created!" -ForegroundColor Cyan
Write-Host "Total users: 25" -ForegroundColor Cyan
Write-Host "Default password: FortReign2026!" -ForegroundColor Yellow