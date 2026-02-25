Import-Module .\480Utils.psm1

# Step 1: Configure the clone
New-VMFromSnapshot -vserver "vcenter.derek.local"

# Step 2: Execute the clone
Invoke-VMClone
