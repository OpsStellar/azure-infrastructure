<#
.SYNOPSIS
    Start or stop an Azure VM with public IP and NSG rule management.

.DESCRIPTION
    STOP:  Removes SSH NSG rule, detaches and deletes the public IP, then deallocates the VM.
    START: Ensures the VM is running, creates/attaches a public IP if missing,
           and adds an SSH NSG rule for the caller's IP if not present.
           Each step is idempotent -- skips if already configured.

.PARAMETER Action
    "start" or "stop".

.EXAMPLE
    .\Manage-AzureVM.ps1 -Action start
    .\Manage-AzureVM.ps1 -Action stop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("start", "stop")]
    [string]$Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------- Configuration ----------
$VmName        = "myVm"
$ResourceGroup = "opsstellar-dev-rg"
$PublicIpName  = "$VmName-pip"
$NsgRuleName   = "Allow-SSH-MyIP"
$SshPort       = 22
$RulePriority  = 1000

# Resolve location and NIC name from the VM
$Location = az vm show --resource-group $ResourceGroup --name $VmName --query location -o tsv
if ($LASTEXITCODE -ne 0) { throw "Failed to get VM location." }

$NicId = az vm show --resource-group $ResourceGroup --name $VmName --query "networkProfile.networkInterfaces[0].id" -o tsv
if ($LASTEXITCODE -ne 0) { throw "Failed to get VM NIC." }
$NicName = ($NicId -split '/')[-1]

# Resolve NSG attached to the NIC
$NsgId = az network nic show --resource-group $ResourceGroup --name $NicName --query "networkSecurityGroup.id" -o tsv
$NsgName = if ($NsgId) { ($NsgId -split '/')[-1] } else { $null }

# Resolve VM zone (for zonal PIP)
$VmZone = az vm show --resource-group $ResourceGroup --name $VmName --query "zones[0]" -o tsv 2>$null

# ---------- Helper: Get caller's public IP ----------
function Get-MyPublicIP {
    $ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 10).Trim()
    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        throw "Failed to resolve public IP. Got: $ip"
    }
    return $ip
}

# ---------- STOP ----------
function Stop-ManagedVM {
    Write-Host "=== Stopping VM: $VmName ===" -ForegroundColor Cyan

    # 1. Remove NSG rule
    if ($NsgName) {
        $ErrorActionPreference = "SilentlyContinue"
        $rule = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $NsgRuleName 2>$null
        $ErrorActionPreference = "Stop"
        if ($rule) {
            Write-Host "Removing NSG rule '$NsgRuleName' from '$NsgName'..."
            az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $NsgRuleName
            Write-Host "NSG rule removed." -ForegroundColor Green
        } else {
            Write-Host "NSG rule '$NsgRuleName' not found -- skipping." -ForegroundColor Yellow
        }
    }

    # 2. Detach public IP from NIC
    $nic = az network nic show --resource-group $ResourceGroup --name $NicName -o json | ConvertFrom-Json
    $currentPipId = if ($nic.ipConfigurations[0].PSObject.Properties['publicIPAddress'] -and $nic.ipConfigurations[0].publicIPAddress) {
        $nic.ipConfigurations[0].publicIPAddress.id
    } else { $null }
    if ($currentPipId) {
        Write-Host "Detaching public IP from NIC '$NicName'..."
        $ipConfigName = $nic.ipConfigurations[0].name
        az network nic ip-config update --resource-group $ResourceGroup --nic-name $NicName --name $ipConfigName --remove publicIpAddress | Out-Null
        Write-Host "Public IP detached." -ForegroundColor Green
    } else {
        Write-Host "No public IP attached -- skipping detach." -ForegroundColor Yellow
    }

    # 3. Delete public IP
    $ErrorActionPreference = "SilentlyContinue"
    $pipExists = az network public-ip show --resource-group $ResourceGroup --name $PublicIpName 2>$null
    $ErrorActionPreference = "Stop"
    if ($pipExists) {
        Write-Host "Deleting public IP '$PublicIpName'..."
        az network public-ip delete --resource-group $ResourceGroup --name $PublicIpName
        Write-Host "Public IP deleted." -ForegroundColor Green
    } else {
        Write-Host "Public IP '$PublicIpName' not found -- skipping delete." -ForegroundColor Yellow
    }

    # 4. Stop (deallocate) VM
    Write-Host "Deallocating VM '$VmName'..."
    az vm deallocate --resource-group $ResourceGroup --name $VmName
    Write-Host "VM deallocated." -ForegroundColor Green

    Write-Host "=== Stop complete ===" -ForegroundColor Cyan
}

# ---------- START ----------
function Start-ManagedVM {
    Write-Host "=== Starting VM: $VmName ===" -ForegroundColor Cyan

    # 1. Check VM power state -- start only if not already running
    $powerState = az vm get-instance-view --resource-group $ResourceGroup --name $VmName --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv
    if ($powerState -eq "PowerState/running") {
        Write-Host "VM '$VmName' is already running -- skipping start." -ForegroundColor Yellow
    } else {
        Write-Host "Starting VM '$VmName' (current state: $powerState)..."
        az vm start --resource-group $ResourceGroup --name $VmName
        Write-Host "VM started." -ForegroundColor Green
    }

    # 2. Check / create public IP
    $ErrorActionPreference = "SilentlyContinue"
    $pipJson = az network public-ip show --resource-group $ResourceGroup --name $PublicIpName 2>$null
    $ErrorActionPreference = "Stop"
    if ($pipJson) {
        $pipAddr = az network public-ip show --resource-group $ResourceGroup --name $PublicIpName --query ipAddress -o tsv
        Write-Host "Public IP '$PublicIpName' already exists ($pipAddr) -- skipping create." -ForegroundColor Yellow
    } else {
        Write-Host "Creating public IP '$PublicIpName'..."
        $pipArgs = @(
            'network', 'public-ip', 'create',
            '--resource-group', $ResourceGroup,
            '--name', $PublicIpName,
            '--location', $Location,
            '--allocation-method', 'Static',
            '--sku', 'Standard'
        )
        if ($VmZone) { $pipArgs += '--zone'; $pipArgs += $VmZone }
        az @pipArgs | Out-Null
        $pipAddr = az network public-ip show --resource-group $ResourceGroup --name $PublicIpName --query ipAddress -o tsv
        Write-Host "Public IP created: $pipAddr" -ForegroundColor Green
    }

    # 3. Check / attach public IP to NIC
    $nic = az network nic show --resource-group $ResourceGroup --name $NicName -o json | ConvertFrom-Json
    $currentPipId = if ($nic.ipConfigurations[0].PSObject.Properties['publicIPAddress'] -and $nic.ipConfigurations[0].publicIPAddress) {
        $nic.ipConfigurations[0].publicIPAddress.id
    } else { $null }
    $targetPipId = az network public-ip show --resource-group $ResourceGroup --name $PublicIpName --query id -o tsv
    if ($currentPipId -eq $targetPipId) {
        Write-Host "Public IP already attached to NIC '$NicName' -- skipping attach." -ForegroundColor Yellow
    } else {
        Write-Host "Attaching public IP to NIC '$NicName'..."
        $ipConfigName = $nic.ipConfigurations[0].name
        az network nic ip-config update `
            --resource-group $ResourceGroup `
            --nic-name $NicName `
            --name $ipConfigName `
            --public-ip-address $PublicIpName | Out-Null
        Write-Host "Public IP attached." -ForegroundColor Green
    }

    # 4. Check / add NSG rule for SSH from caller's IP
    $myIP = Get-MyPublicIP
    Write-Host "My public IP: $myIP"

    if (-not $NsgName) {
        throw "No NSG associated with NIC '$NicName'. Cannot add SSH rule."
    }

    $ErrorActionPreference = "SilentlyContinue"
    $existingSource = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $NsgRuleName --query sourceAddressPrefix -o tsv 2>$null
    $ErrorActionPreference = "Stop"
    if ($existingSource -eq "$myIP/32") {
        Write-Host "NSG rule '$NsgRuleName' already allows SSH from $myIP -- skipping." -ForegroundColor Yellow
    } else {
        # Delete stale rule if source IP changed
        if ($existingSource) {
            Write-Host "Updating NSG rule '$NsgRuleName' (old source: $existingSource)..."
            az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $NsgRuleName
        }

        Write-Host "Adding NSG rule '$NsgRuleName' (SSH from $myIP)..."
        az network nsg rule create `
            --resource-group $ResourceGroup `
            --nsg-name $NsgName `
            --name $NsgRuleName `
            --priority $RulePriority `
            --direction Inbound `
            --access Allow `
            --protocol Tcp `
            --source-address-prefixes "$myIP/32" `
            --source-port-ranges '*' `
            --destination-address-prefixes '*' `
            --destination-port-ranges $SshPort | Out-Null
        Write-Host "NSG rule added." -ForegroundColor Green
    }

    # Summary
    $pipAddr = az network public-ip show --resource-group $ResourceGroup --name $PublicIpName --query ipAddress -o tsv
    Write-Host ""
    Write-Host "=== Start complete ===" -ForegroundColor Cyan
    Write-Host "Public IP : $pipAddr"
    Write-Host "SSH       : ssh <user>@$pipAddr"
}

# ---------- Main ----------
switch ($Action) {
    "stop"  { Stop-ManagedVM }
    "start" { Start-ManagedVM }
}
