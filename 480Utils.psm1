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
        
        # Select Datastore
        Write-Host "`nAvailable Datastores:"
        Get-Datastore | Format-Table -AutoSize
        do {
            $datastore = Read-Host -Prompt "Select your datastore"
            if ([string]::IsNullOrWhiteSpace($datastore)) {
                Write-Host "Datastore cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($datastore))
        
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
        "datastore": "$datastore",
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

function Invoke-VMClone {
    <#
    .SYNOPSIS
        Clones a VM from a snapshot using linked clone method
    
    .DESCRIPTION
        Creates a linked clone from a snapshot, then creates a full clone, 
        takes a new base snapshot, and removes the linked clone
    
    .PARAMETER ConfigPath
        Path to config.json file (default: Desktop\config.json)
    
    .EXAMPLE
        Invoke-VMClone
        Invoke-VMClone -ConfigPath "C:\path\to\config.json"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = (Join-Path ([Environment]::GetFolderPath("Desktop")) "config.json")
    )
    
    try {
        # Check if config exists
        if (-not (Test-Path $ConfigPath)) {
            throw "Config file not found at: $ConfigPath. Please run New-VMFromSnapshot first."
        }
        
        # Read config
        Write-Host "Reading config from: $ConfigPath"
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Validate config has required fields
        if ([string]::IsNullOrWhiteSpace($config.current.srcVM)) {
            throw "Source VM not found in config. Please run New-VMFromSnapshot first."
        }
        
        # Get VM objects
        Write-Host "Getting VM: $($config.current.srcVM)"
        $vm = Get-VM -Name $config.current.srcVM -ErrorAction Stop
        
        Write-Host "Getting snapshot: $($config.current.snapshot)"
        $snapshot = Get-Snapshot -VM $vm -Name $config.current.snapshot -ErrorAction Stop
        
        Write-Host "Getting VM Host: $($config.current.VMHost)"
        $vmhost = Get-VMHost -Name $config.current.VMHost -ErrorAction Stop
        
        Write-Host "Getting Datastore: $($config.current.datastore)"
        $ds = Get-Datastore -Name $config.current.datastore -ErrorAction Stop
        
        # Create linked clone
        $linkedClone = "{0}.linked" -f $vm.name
        Write-Host "Creating linked clone: $linkedClone"
        $linkedvm = New-VM -LinkedClone -Name $linkedClone -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds
        
        # Create full clone
        Write-Host "Creating full clone: $($config.current.newVMName)"
        $newvm = New-VM -Name $config.current.newVMName -VM $linkedvm -VMHost $vmhost -Datastore $ds
        
        # Create base snapshot
        Write-Host "Creating base snapshot"
        $newvm | New-Snapshot -Name "Base"
        
        # Remove linked clone
        Write-Host "Removing linked clone"
        $linkedvm | Remove-VM -Confirm:$false
        
        Write-Host "Successfully cloned VM: $($config.current.newVMName)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to clone VM: $_"
        throw
    }
}

# Export the functions
Export-ModuleMember -Function New-VMFromSnapshot, Invoke-VMClone
