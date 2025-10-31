"""
Pulumi Infrastructure as Code for OpsVerse SaaS on Azure
Basic setup with Networking, ACR, and AKS
"""

import pulumi
import pulumi_azure_native as azure_native
import pulumi_kubernetes as k8s
from pulumi import Output, export

# Configuration
config = pulumi.Config()
azure_config = pulumi.Config("azure-native")

# Azure Configuration
location = azure_config.get("location") or "eastus"

# Project Configuration
project_name = config.get("project_name") or "opsstellar"
environment = config.get("environment") or "dev"

# Kubernetes Configuration
k8s_version = config.get("k8s_version") or "1.28.3"
node_count = config.get_int("node_count") or 2
node_vm_size = config.get("node_vm_size") or "Standard_B2s"
min_node_count = config.get_int("min_node_count") or 1
max_node_count = config.get_int("max_node_count") or 3

# Network Configuration
vnet_address_space = config.get("vnet_address_space") or "10.0.0.0/16"
aks_subnet_prefix = config.get("aks_subnet_prefix") or "10.0.0.0/20"
service_cidr = config.get("service_cidr") or "10.1.0.0/16"
dns_service_ip = config.get("dns_service_ip") or "10.1.0.10"

# ACR Configuration
acr_sku = config.get("acr_sku") or "Basic"

# Resource naming
resource_prefix = f"{project_name}-{environment}"

# Tags for all resources
tags = {
    "Project": project_name,
    "Environment": environment,
    "ManagedBy": "Pulumi"
}

# 1. Resource Group
resource_group = azure_native.resources.ResourceGroup(
    f"{resource_prefix}-rg",
    location=location,
    resource_group_name=f"{resource_prefix}-rg",
    tags=tags
)

# 2. Azure Container Registry
acr = azure_native.containerregistry.Registry(
    f"{resource_prefix}-acr",
    resource_group_name=resource_group.name,
    location=location,
    registry_name=f"{project_name}{environment}acr".replace("-", ""),  # ACR name must be alphanumeric
    sku=azure_native.containerregistry.SkuArgs(
        name=acr_sku
    ),
    admin_user_enabled=True,  # Enable admin for CI/CD
    tags=tags
)

# Get ACR credentials
acr_credentials = pulumi.Output.all(resource_group.name, acr.name).apply(
    lambda args: azure_native.containerregistry.list_registry_credentials(
        resource_group_name=args[0],
        registry_name=args[1]
    )
)

# 3. Virtual Network
vnet = azure_native.network.VirtualNetwork(
    f"{resource_prefix}-vnet",
    resource_group_name=resource_group.name,
    location=location,
    virtual_network_name=f"{resource_prefix}-vnet",
    address_space=azure_native.network.AddressSpaceArgs(
        address_prefixes=[vnet_address_space]
    ),
    tags=tags
)

# AKS Subnet
aks_subnet = azure_native.network.Subnet(
    f"{resource_prefix}-aks-subnet",
    resource_group_name=resource_group.name,
    virtual_network_name=vnet.name,
    subnet_name=f"{resource_prefix}-aks-subnet",
    address_prefix=aks_subnet_prefix
)

# 4. Azure Kubernetes Service (AKS)
aks_cluster = azure_native.containerservice.ManagedCluster(
    f"{resource_prefix}-aks",
    resource_group_name=resource_group.name,
    location=location,
    dns_prefix=f"{resource_prefix}-aks",
    kubernetes_version=k8s_version,
    enable_rbac=True,
    
    # Identity
    identity=azure_native.containerservice.ManagedClusterIdentityArgs(
        type=azure_native.containerservice.ResourceIdentityType.SYSTEM_ASSIGNED
    ),
    
    # Network Profile
    network_profile=azure_native.containerservice.ContainerServiceNetworkProfileArgs(
        network_plugin="azure",
        service_cidr=service_cidr,
        dns_service_ip=dns_service_ip,
        load_balancer_sku="standard"
    ),
    
    # Agent Pool (Node Pool)
    agent_pool_profiles=[
        azure_native.containerservice.ManagedClusterAgentPoolProfileArgs(
            name="nodepool1",
            count=node_count,
            vm_size=node_vm_size,
            os_type="Linux",
            mode="System",
            enable_auto_scaling=True,
            min_count=min_node_count,
            max_count=max_node_count,
            vnet_subnet_id=aks_subnet.id,
            type="VirtualMachineScaleSets"
        )
    ],
    
    tags=tags
)

# Get AKS credentials
aks_creds = pulumi.Output.all(resource_group.name, aks_cluster.name).apply(
    lambda args: azure_native.containerservice.list_managed_cluster_user_credentials(
        resource_group_name=args[0],
        resource_name=args[1]
    )
)

# Decode kubeconfig
kubeconfig = aks_creds.apply(
    lambda creds: creds.kubeconfigs[0].value.decode("utf-8") if creds.kubeconfigs else ""
)

# Create Kubernetes provider using the AKS cluster's kubeconfig
k8s_provider = k8s.Provider(
    f"{resource_prefix}-k8s-provider",
    kubeconfig=kubeconfig
)

# Attach ACR to AKS (grant AKS pull access to ACR)
acr_assignment = azure_native.authorization.RoleAssignment(
    f"{resource_prefix}-aks-acr-pull",
    principal_id=aks_cluster.identity_profile.apply(
        lambda profile: profile["kubeletidentity"].object_id if profile else ""
    ),
    principal_type="ServicePrincipal",
    role_definition_id=f"/subscriptions/{azure_native.authorization.get_client_config().subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d",  # AcrPull role
    scope=acr.id
)

# Exports
export("resource_group_name", resource_group.name)
export("acr_login_server", acr.login_server)
export("acr_admin_username", acr_credentials.apply(lambda c: c.username))
export("aks_cluster_name", aks_cluster.name)
export("aks_cluster_fqdn", aks_cluster.fqdn)
export("kubeconfig", kubeconfig)
export("vnet_id", vnet.id)
export("aks_subnet_id", aks_subnet.id)
