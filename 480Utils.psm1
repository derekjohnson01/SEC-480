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
        Start-Sleep -Seconds 5
        
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

function New-Network {
    try {
        # Show available VMHosts and select one
        Write-Host "`nAvailable VMHosts:" -ForegroundColor Cyan
        Get-VMHost -ErrorAction Stop | Format-Table -AutoSize

        do {
            $vmHostName = Read-Host -Prompt "Enter the VMHost name to create the virtual switch on"
            if ([string]::IsNullOrWhiteSpace($vmHostName)) {
                Write-Host "VMHost name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($vmHostName))

        # Required: Virtual Switch Name
        do {
            $vSwitchName = Read-Host -Prompt "Enter a name for the new virtual switch"
            if ([string]::IsNullOrWhiteSpace($vSwitchName)) {
                Write-Host "Virtual switch name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($vSwitchName))

        # Create the virtual switch
        New-VirtualSwitch -VMHost $vmHostName -Name $vSwitchName -ErrorAction Stop
        Write-Host "`nVirtual switch '$vSwitchName' created successfully." -ForegroundColor Green

        # Show available virtual switches on the host
        Write-Host "`nAvailable Virtual Switches on host '$vmHostName':" -ForegroundColor Cyan
        Get-VirtualSwitch -VMHost $vmHostName -ErrorAction Stop | Format-Table -AutoSize

        do {
            $selectedSwitch = Read-Host -Prompt "Enter the virtual switch name to create a port group on"
            if ([string]::IsNullOrWhiteSpace($selectedSwitch)) {
                Write-Host "Virtual switch name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($selectedSwitch))

        # Required: Port Group Name
        do {
            $pgName = Read-Host -Prompt "Enter a name for the new port group"
            if ([string]::IsNullOrWhiteSpace($pgName)) {
                Write-Host "Port group name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($pgName))

        # Create the port group — VirtualSwitch requires an object
        $virtualSwitch = Get-VirtualSwitch -VMHost $vmHostName -Name $selectedSwitch -ErrorAction Stop
        New-VirtualPortGroup -Name $pgName -VirtualSwitch $virtualSwitch -ErrorAction Stop
        Write-Host "`nPort group '$pgName' created successfully on switch '$selectedSwitch'." -ForegroundColor Green

    }
    catch {
        Write-Error "Failed in New-Network: $_"
        throw
    }
}

function Get-Network {
    try {
        # Show available VMs
        Write-Host "`nAvailable VMs:" -ForegroundColor Cyan
        Get-VM -ErrorAction Stop | Format-Table -AutoSize

        do {
            $vmName = Read-Host -Prompt "Enter the VM name to get network info on"
            if ([string]::IsNullOrWhiteSpace($vmName)) {
                Write-Host "VM name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($vmName))

        # Get network adapters — accepts string
        Write-Host "`nNetwork Adapters for '$vmName':" -ForegroundColor Cyan
        Get-NetworkAdapter -VM $vmName -ErrorAction Stop | Format-Table -AutoSize

        # Get IP — requires VM object for .Guest.IPAddress
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        $ipAddress = $vm.Guest.IPAddress[0]
        Write-Host "`nPrimary IP Address: $ipAddress" -ForegroundColor Green

    }
    catch {
        Write-Error "Failed in Get-Network: $_"
        throw
    }
}

function Start-VMInteractive {
    try {
        # Get all powered off VMs
        $poweredOffVMs = Get-VM -ErrorAction Stop | Where-Object { $_.PowerState -eq "PoweredOff" }

        if ($poweredOffVMs.Count -eq 0) {
            Write-Host "No powered off VMs found." -ForegroundColor Yellow
            return
        }

        Write-Host "`nPowered Off VMs:" -ForegroundColor Cyan
        $poweredOffVMs | Format-Table -Property Name, PowerState -AutoSize

        do {
            $selection = Read-Host "Enter the name of the VM you want to start"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                Write-Host "VM name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($selection))

        Start-VM -VM $selection -Confirm:$false -ErrorAction Stop
        Write-Host "$selection started successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed in Start-VMInteractive: $_"
        throw
    }
}

function Stop-VMInteractive {
    try {
        # Get all powered on VMs
        $poweredOnVMs = Get-VM -ErrorAction Stop | Where-Object { $_.PowerState -eq "PoweredOn" }

        if ($poweredOnVMs.Count -eq 0) {
            Write-Host "No powered on VMs found." -ForegroundColor Yellow
            return
        }

        Write-Host "`nPowered On VMs:" -ForegroundColor Cyan
        $poweredOnVMs | Format-Table -Property Name, PowerState -AutoSize

        do {
            $selection = Read-Host "Enter the name of the VM you want to stop"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                Write-Host "VM name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($selection))

        Stop-VM -VM $selection -Confirm:$false -ErrorAction Stop
        Write-Host "$selection stopped successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed in Stop-VMInteractive: $_"
        throw
    }
}

function Set-Network {
    try {
        # Show available VMs
        Write-Host "`nAvailable VMs:" -ForegroundColor Cyan
        Get-VM -ErrorAction Stop | Format-Table -AutoSize
        do {
            $vmName = Read-Host -Prompt "Enter the VM name to configure the network adapter on"
            if ([string]::IsNullOrWhiteSpace($vmName)) {
                Write-Host "VM name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($vmName))

        # Get all adapters and display them numbered
        $adapters = Get-NetworkAdapter -VM $vmName -ErrorAction Stop
        Write-Host "`nNetwork Adapters for '$vmName':" -ForegroundColor Cyan
        for ($i = 0; $i -lt $adapters.Count; $i++) {
            Write-Host "  [$i] $($adapters[$i].Name) - $($adapters[$i].NetworkName)" -ForegroundColor White
        }

        # Let user pick which adapters to configure
        do {
            $selection = Read-Host -Prompt "`nEnter adapter numbers to configure (comma-separated, e.g. 0,1,2)"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                Write-Host "Selection cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($selection))

        $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() }

        # Show available virtual networks
        Write-Host "`nAvailable Virtual Networks:" -ForegroundColor Cyan
        Get-VirtualNetwork -ErrorAction Stop | Format-Table -AutoSize
        do {
            $networkName = Read-Host -Prompt "Enter the virtual network name to assign"
            if ([string]::IsNullOrWhiteSpace($networkName)) {
                Write-Host "Network name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrWhiteSpace($networkName))

        # Loop through selected adapters and assign the network
        foreach ($i in $indices) {
            if ($i -lt 0 -or $i -ge $adapters.Count) {
                Write-Host "Skipping invalid index: $i" -ForegroundColor Yellow
                continue
            }
            $adapter = $adapters[$i]
            Write-Host "Setting $($adapter.Name) -> $networkName"
            Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $networkName -Confirm:$false -ErrorAction Stop
            Write-Host "  Done." -ForegroundColor Green
        }

        Write-Host "`nAll selected adapters assigned to '$networkName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed in Set-Network: $_"
        throw
    }
}

# Export the functions
Export-ModuleMember -Function New-VMFromSnapshot, Invoke-VMClone, New-Network, Get-Network, Set-Network, Start-VMInteractive, Stop-VMInteractive