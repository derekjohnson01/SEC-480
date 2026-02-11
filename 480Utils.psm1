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
        $srcVM = Read-Host -Prompt "Select your source VM"
        
        # Select snapshot
        Write-Host "`nAvailable Snapshots:" 
        Get-Snapshot -VM $srcVM | Format-Table -AutoSize
        $snapshot = Read-Host -Prompt "Select your snapshot"
        
        # Select datacenter
        Write-Host "`nAvailable Datacenters:"
        Get-Datacenter | Format-Table -AutoSize
        $dc = Read-Host -Prompt "Select your datacenter"
        
        # Select VM Host
        Write-Host "`nAvailable VM Hosts:"
        Get-VMHost | Format-Table -AutoSize
        $VMHost = Read-Host -Prompt "Select your VM Host"
        
        # Set new VM name
        $newName = Read-Host -Prompt "Set the new VM name"

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
        Write-Host "Successfully updated config.json at: $configPath"
    }
    catch {
        Write-Error "Failed to update config.json: $_"
        throw
    }
}

# Export the function
Export-ModuleMember -Function New-VMFromSnapshot