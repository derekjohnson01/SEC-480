Import-Module .\480Utils.psm1 -Force
Write-Host "=== 480Utils Test Suite ===" -ForegroundColor Magenta

# Authenticate with vCenter Server
Write-Host "`n--- Connecting to vCenter Server ---" -ForegroundColor Cyan
$vserver = Read-Host "Enter vCenter Server address"
$creds = Get-Credential -Message "Enter vCenter credentials"
Connect-VIServer -Server $vserver -Credential $creds
Write-Host "Connected to $vserver successfully." -ForegroundColor Green

<#
# Step 1: Configure the clone
Write-Host "`n--- Test: New-VMFromSnapshot ---"  -ForegroundColor Yellow
New-VMFromSnapshot

# Step 2: Execute the clone
Write-Host "`n--- Test: Invoke-VMClone ---" -ForegroundColor Yellow
Invoke-VMClone

# Step 3: Create a virtual switch and port group
Write-Host "`n--- Test: New-Network ---" -ForegroundColor Yellow
New-Network

# Step 4: Get network info on a VM
Write-Host "`n--- Test: Get-Network ---" -ForegroundColor Yellow
Get-Network
#>

# Step 5: Assign a network adapter to a network
Write-Host "`n--- Test: Set-Network ---" -ForegroundColor Yellow
Set-Network

<#
# Step 6: Start a powered off VM
Write-Host "`n--- Test: Start-VMInteractive ---" -ForegroundColor Yellow
Start-VMInteractive

# Step 7: Stop a powered on VM
Write-Host "`n--- Test: Stop-VMInteractive ---" -ForegroundColor Yellow
Stop-VMInteractive

Write-Host "`n=== Test Suite Complete ===" -ForegroundColor Magenta
#>