#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Manage-AzureVM.sh -- Start or stop an Azure VM with public IP & NSG rules
#
# Usage:
#   ./manage-azure-vm.sh start
#   ./manage-azure-vm.sh stop
#
# START: Ensures VM is running, creates/attaches public IP if missing,
#        adds SSH NSG rule for caller's IP if not present.
# STOP:  Removes SSH NSG rule, detaches & deletes public IP, deallocates VM.
# Each step is idempotent -- skips if already configured.
# ---------------------------------------------------------------------------
set -euo pipefail

# ---------- Configuration ----------
VM_NAME="myVm"
RESOURCE_GROUP="opsstellar-dev-rg"
PUBLIC_IP_NAME="${VM_NAME}-pip"
NSG_RULE_NAME="Allow-SSH-MyIP"
SSH_PORT=22
RULE_PRIORITY=1000

# ---------- Resolve infrastructure ----------
LOCATION=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query location -o tsv) \
    || { echo "ERROR: Failed to get VM location." >&2; exit 1; }

NIC_ID=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" -o tsv) \
    || { echo "ERROR: Failed to get VM NIC." >&2; exit 1; }
NIC_NAME="${NIC_ID##*/}"

NSG_ID=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" \
    --query "networkSecurityGroup.id" -o tsv 2>/dev/null || true)
NSG_NAME="${NSG_ID##*/}"

VM_ZONE=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" \
    --query "zones[0]" -o tsv 2>/dev/null || true)

# ---------- Colours ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ---------- Helper: caller's public IP ----------
get_my_public_ip() {
    local ip
    ip=$(curl -s --max-time 10 "https://api.ipify.org?format=text")
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: Failed to resolve public IP. Got: $ip" >&2
        exit 1
    fi
    echo "$ip"
}

# ---------- STOP ----------
stop_managed_vm() {
    echo -e "${CYAN}=== Stopping VM: $VM_NAME ===${NC}"

    # 1. Remove NSG rule
    if [[ -n "$NSG_NAME" ]]; then
        if az network nsg rule show --resource-group "$RESOURCE_GROUP" \
                --nsg-name "$NSG_NAME" --name "$NSG_RULE_NAME" &>/dev/null; then
            echo "Removing NSG rule '$NSG_RULE_NAME' from '$NSG_NAME'..."
            az network nsg rule delete --resource-group "$RESOURCE_GROUP" \
                --nsg-name "$NSG_NAME" --name "$NSG_RULE_NAME"
            echo -e "${GREEN}NSG rule removed.${NC}"
        else
            echo -e "${YELLOW}NSG rule '$NSG_RULE_NAME' not found -- skipping.${NC}"
        fi
    fi

    # 2. Detach public IP from NIC
    local current_pip_id
    current_pip_id=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" \
        --query "ipConfigurations[0].publicIpAddress.id" -o tsv 2>/dev/null || true)
    if [[ -n "$current_pip_id" && "$current_pip_id" != "None" ]]; then
        local ip_config_name
        ip_config_name=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" \
            --query "ipConfigurations[0].name" -o tsv)
        echo "Detaching public IP from NIC '$NIC_NAME'..."
        az network nic ip-config update --resource-group "$RESOURCE_GROUP" \
            --nic-name "$NIC_NAME" --name "$ip_config_name" --remove publicIpAddress -o none
        echo -e "${GREEN}Public IP detached.${NC}"
    else
        echo -e "${YELLOW}No public IP attached -- skipping detach.${NC}"
    fi

    # 3. Delete public IP
    if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" &>/dev/null; then
        echo "Deleting public IP '$PUBLIC_IP_NAME'..."
        az network public-ip delete --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME"
        echo -e "${GREEN}Public IP deleted.${NC}"
    else
        echo -e "${YELLOW}Public IP '$PUBLIC_IP_NAME' not found -- skipping delete.${NC}"
    fi

    # 4. Deallocate VM
    echo "Deallocating VM '$VM_NAME'..."
    az vm deallocate --resource-group "$RESOURCE_GROUP" --name "$VM_NAME"
    echo -e "${GREEN}VM deallocated.${NC}"

    echo -e "${CYAN}=== Stop complete ===${NC}"
}

# ---------- START ----------
start_managed_vm() {
    echo -e "${CYAN}=== Starting VM: $VM_NAME ===${NC}"

    # 1. Check VM power state -- start only if not already running
    local power_state
    power_state=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" \
        --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv)
    if [[ "$power_state" == "PowerState/running" ]]; then
        echo -e "${YELLOW}VM '$VM_NAME' is already running -- skipping start.${NC}"
    else
        echo "Starting VM '$VM_NAME' (current state: $power_state)..."
        az vm start --resource-group "$RESOURCE_GROUP" --name "$VM_NAME"
        echo -e "${GREEN}VM started.${NC}"
    fi

    # 2. Check / create public IP
    if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" &>/dev/null; then
        local pip_addr
        pip_addr=$(az network public-ip show --resource-group "$RESOURCE_GROUP" \
            --name "$PUBLIC_IP_NAME" --query ipAddress -o tsv)
        echo -e "${YELLOW}Public IP '$PUBLIC_IP_NAME' already exists ($pip_addr) -- skipping create.${NC}"
    else
        echo "Creating public IP '$PUBLIC_IP_NAME'..."
        local -a pip_args=(
            --resource-group "$RESOURCE_GROUP"
            --name "$PUBLIC_IP_NAME"
            --location "$LOCATION"
            --allocation-method Static
            --sku Standard
        )
        if [[ -n "$VM_ZONE" ]]; then
            pip_args+=(--zone "$VM_ZONE")
        fi
        az network public-ip create "${pip_args[@]}" -o none
        pip_addr=$(az network public-ip show --resource-group "$RESOURCE_GROUP" \
            --name "$PUBLIC_IP_NAME" --query ipAddress -o tsv)
        echo -e "${GREEN}Public IP created: $pip_addr${NC}"
    fi

    # 3. Check / attach public IP to NIC
    local current_pip_id target_pip_id ip_config_name
    current_pip_id=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" \
        --query "ipConfigurations[0].publicIpAddress.id" -o tsv 2>/dev/null || true)
    target_pip_id=$(az network public-ip show --resource-group "$RESOURCE_GROUP" \
        --name "$PUBLIC_IP_NAME" --query id -o tsv)
    if [[ "$current_pip_id" == "$target_pip_id" ]]; then
        echo -e "${YELLOW}Public IP already attached to NIC '$NIC_NAME' -- skipping attach.${NC}"
    else
        ip_config_name=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" \
            --query "ipConfigurations[0].name" -o tsv)
        echo "Attaching public IP to NIC '$NIC_NAME'..."
        az network nic ip-config update \
            --resource-group "$RESOURCE_GROUP" \
            --nic-name "$NIC_NAME" \
            --name "$ip_config_name" \
            --public-ip-address "$PUBLIC_IP_NAME" -o none
        echo -e "${GREEN}Public IP attached.${NC}"
    fi

    # 4. Check / add NSG rule for SSH from caller's IP
    local my_ip
    my_ip=$(get_my_public_ip)
    echo "My public IP: $my_ip"

    if [[ -z "$NSG_NAME" ]]; then
        echo "ERROR: No NSG associated with NIC '$NIC_NAME'. Cannot add SSH rule." >&2
        exit 1
    fi

    local existing_source
    existing_source=$(az network nsg rule show --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$NSG_NAME" --name "$NSG_RULE_NAME" \
        --query sourceAddressPrefix -o tsv 2>/dev/null || true)
    if [[ "$existing_source" == "$my_ip/32" ]]; then
        echo -e "${YELLOW}NSG rule '$NSG_RULE_NAME' already allows SSH from $my_ip -- skipping.${NC}"
    else
        if [[ -n "$existing_source" ]]; then
            echo "Updating NSG rule '$NSG_RULE_NAME' (old source: $existing_source)..."
            az network nsg rule delete --resource-group "$RESOURCE_GROUP" \
                --nsg-name "$NSG_NAME" --name "$NSG_RULE_NAME"
        fi
        echo "Adding NSG rule '$NSG_RULE_NAME' (SSH from $my_ip)..."
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "$NSG_RULE_NAME" \
            --priority "$RULE_PRIORITY" \
            --direction Inbound \
            --access Allow \
            --protocol Tcp \
            --source-address-prefixes "$my_ip/32" \
            --source-port-ranges '*' \
            --destination-address-prefixes '*' \
            --destination-port-ranges "$SSH_PORT" -o none
        echo -e "${GREEN}NSG rule added.${NC}"
    fi

    # Summary
    pip_addr=$(az network public-ip show --resource-group "$RESOURCE_GROUP" \
        --name "$PUBLIC_IP_NAME" --query ipAddress -o tsv)
    echo ""
    echo -e "${CYAN}=== Start complete ===${NC}"
    echo "Public IP : $pip_addr"
    echo "SSH       : ssh <user>@$pip_addr"
}

# ---------- Main ----------
ACTION="${1:-}"
case "$ACTION" in
    start) start_managed_vm ;;
    stop)  stop_managed_vm ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac
