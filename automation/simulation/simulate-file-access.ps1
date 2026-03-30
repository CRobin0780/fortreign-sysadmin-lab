# Simulate-FileAccess.ps1
# Generates realistic file access patterns across department shares

param(
    [int]$DurationMinutes = 60
)

$ShareRoot = "C:\Shares"
$EndTime = (Get-Date).AddMinutes($DurationMinutes)

Write-Host "[*] Starting file access simulation..." -ForegroundColor Cyan

while ((Get-Date) -lt $EndTime) {
    # Pick random department share
    $dept = @("Finance", "IT", "HR", "Sales", "Operations", "Public") | Get-Random
    $sharePath = "$ShareRoot\$dept\Documents"
    
    # Get files in share
    $files = Get-ChildItem -Path $sharePath -File -ErrorAction SilentlyContinue
    
    if ($files) {
        $randomFile = $files | Get-Random
        
        # Simulate read (80% of time) or write (20% of time)
        $action = if ((Get-Random -Minimum 1 -Maximum 100) -le 80) { "Read" } else { "Write" }
        
        try {
            if ($action -eq "Read") {
                $null = Get-Content -Path $randomFile.FullName -TotalCount 10
            } else {
                "[$(Get-Date)] Simulated user edit" | Add-Content -Path $randomFile.FullName
            }
            
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $action - $dept\$($randomFile.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error accessing $dept\$($randomFile.Name)" -ForegroundColor Red
        }
    }
    
    # Delay 30-120 seconds between accesses
    Start-Sleep -Seconds (Get-Random -Minimum 30 -Maximum 120)
}

Write-Host "`n✅ File access simulation complete!" -ForegroundColor Cyan