param([int]$DurationMinutes = 60, [string]$TargetComputer = "LAB-W10-01")
$Users = @("ehale","mkeene","nvance","pnair","cortiz","jrios","dmorris","spark","mking","obishop","mchen","gsutter","akhan","jhart","lrowe","bibrahim","tmiles","dsantos","vlang","npatel","ewells","cbennett","rdiaz","hfoster","istone")
$Password = ConvertTo-SecureString "FortReign2026!" -AsPlainText -Force
Write-Host "[*] Fort Reign activity simulation - $DurationMinutes min | Target: $TargetComputer | Users: $($Users.Count)" -ForegroundColor Cyan
$EndTime = (Get-Date).AddMinutes($DurationMinutes); $successCount = 0; $failCount = 0
while ((Get-Date) -lt $EndTime) {
    $Username = $Users | Get-Random
    try {
        $Credential = New-Object System.Management.Automation.PSCredential("lab\$Username", $Password)
        $null = Get-WmiObject -Class Win32_Process -ComputerName $TargetComputer -Credential $Credential -ErrorAction Stop
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ? $Username" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ? $Username" -ForegroundColor Yellow
        $failCount++
    }
    Start-Sleep -Seconds (Get-Random -Minimum 60 -Maximum 300)
}
Write-Host "`n? Complete! Success: $successCount | Failed: $failCount" -ForegroundColor Cyan
