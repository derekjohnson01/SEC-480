function New-VMFromSnapshot {
    <#
    .SYNOPSIS
        Creates a new VM from an existing VM snapshot
    
    .DESCRIPTION
        Connects to vCenter and guides user through cloning a VM from a snapshot
    
    .PARAMETER vserver
        vCenter server address (default: vcenter.derek.local)
    
    .EXAMPLE
        New-VMFromSnapshot
        New-VMFromSnapshot -vserver "vcenter.prod.local"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$vserver = "vcenter.derek.local"
    )
    
    try {
        # Connect to vCenter
        Write-Host "Connecting to vCenter: $vserver" 
        Connect-VIServer $vserver -ErrorAction Stop
        
        # Select source VM
        Write-Host "`nAvailable VMs:" 
        Get-VM | Format-Table -AutoSize
        do {
            $srcVM = Read-Host -Prompt "Select your source VM"
            if ([string]::IsNullOrWhiteSpace($srcVM)) {
                Write-Host "VM name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($srcVM))
        
        # Select snapshot
        Write-Host "`nAvailable Snapshots:" 
        Get-Snapshot -VM $srcVM | Format-Table -AutoSize
        do {
            $snapshot = Read-Host -Prompt "Select your snapshot"
            if ([string]::IsNullOrWhiteSpace($snapshot)) {
                Write-Host "Snapshot name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($snapshot))
        
        # Select datacenter
        Write-Host "`nAvailable Datacenters:"
        Get-Datacenter | Format-Table -AutoSize
        do {
            $dc = Read-Host -Prompt "Select your datacenter"
            if ([string]::IsNullOrWhiteSpace($dc)) {
                Write-Host "Datacenter name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($dc))
        
        # Select VM Host
        Write-Host "`nAvailable VM Hosts:"
        Get-VMHost | Format-Table -AutoSize
        do {
            $VMHost = Read-Host -Prompt "Select your VM Host"
            if ([string]::IsNullOrWhiteSpace($VMHost)) {
                Write-Host "VM Host cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($VMHost))
        
        # Set new VM name
        do {
            $newName = Read-Host -Prompt "Set the new VM name"
            if ([string]::IsNullOrWhiteSpace($newName)) {
                Write-Host "VM name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($newName))

        # build json
        $configJson = @"
{
    "current": {
        "vserver": "$vserver",
        "srcVM": "$srcVM",
        "snapshot": "$snapshot",
        "dc": "$dc",
        "VMHost": "$VMHost",
        "newVMName": "$newName"
    }
}
"@

        # Write to Desktop
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $configPath = Join-Path $desktopPath "config.json"
        $configJson | Out-File -FilePath $configPath -Encoding UTF8

        # output 
        Write-Host "Successfully updated config.json at: $configPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to update config.json: $_"
        throw
    }
}