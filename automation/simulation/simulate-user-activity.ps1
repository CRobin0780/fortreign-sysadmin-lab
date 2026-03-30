# Simulate-UserActivity.ps1
# Simulates realistic user logon patterns during business hours (8 AM - 6 PM)

param(
    [int]$DurationMinutes = 60,
    [string]$TargetComputer = "LAB-W10-01"
)

$Users = @(
    "schen", "mjohnson", "erodriguez", "dkim", "jthompson",  # Finance
    "janderson", "lmartinez", "kbrown", "adavis", "rwilson", "mgarcia",  # IT
    "jtaylor", "clee", "awhite", "dharris",  # HR
    "pmartin", "tmoore", "ljackson", "wthomas", "ewright", "clopez",  # Sales
    "shill", "kgreen", "jbaker", "nadams"  # Operations
)

$Password = ConvertTo-SecureString "LabPass2024!" -AsPlainText -Force

Write-Host "[*] Starting simulated user activity for $DurationMinutes minutes..." -ForegroundColor Cyan

$EndTime = (Get-Date).AddMinutes($DurationMinutes)

while ((Get-Date) -lt $EndTime) {
    # Select random user
    $Username = $Users | Get-Random
    
    # Simulate logon (query AD for auth, generates EventID 4624/4625)
    try {
        $Credential = New-Object System.Management.Automation.PSCredential("lab\$Username", $Password)
        
        # Generate authentication event by attempting to access a share
        $null = Get-WmiObject -Class Win32_Process -ComputerName $TargetComputer -Credential $Credential -ErrorAction SilentlyContinue
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Simulated activity: $Username" -ForegroundColor Green
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ! Failed activity: $Username" -ForegroundColor Yellow
    }
    
    # Random delay between 1-5 minutes
    $delay = Get-Random -Minimum 60 -Maximum 300
    Start-Sleep -Seconds $delay
}

Write-Host "`n✅ Activity simulation complete!" -ForegroundColor Cyan