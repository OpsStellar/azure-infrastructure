"""
Pulumi Infrastructure as Code for OpsVerse SaaS on Azure Kubernetes Service (AKS)
Production-ready with service mesh (Istio), service discovery, and multi-environment support
"""

import pulumi
import pulumi_azure_native as azure_native
import pulumi_kubernetes as k8s
from pulumi import Output, export
import json

# Configuration
config = pulumi.Config()
location = config.get("location") or "eastus"
environment = config.get("environment") or "production"
project_name = "opsverse"

# AKS Configuration
k8s_version = config.get("k8s_version") or "1.28.3"
node_count = config.get_int("node_count") or 2
node_vm_size = config.get("node_vm_size") or "Standard_B2s"  # 2 vCPU, 4GB RAM
enable_autoscaling = config.get_bool("enable_autoscaling") or True
min_node_count = config.get_int("min_node_count") or 2
max_node_count = config.get_int("max_node_count") or 5

# Service Mesh Configuration
enable_istio = config.get_bool("enable_istio") or True
enable_monitoring = config.get_bool("enable_monitoring") or True

# Resource naming
resource_prefix = f"{project_name}-{environment}"

# Tags for all resources
tags = {
    "Project": "OpsVerse",
    "Environment": environment,
    "ManagedBy": "Pulumi",
    "CostCenter": "Engineering"
}

# 1. Resource Group
resource_group = azure_native.resources.ResourceGroup(
    f"{resource_prefix}-rg",
    location=location,
    resource_group_name=f"{resource_prefix}-rg",
    tags=tags
)

# 2. Virtual Network for AKS
vnet = azure_native.network.VirtualNetwork(
    f"{resource_prefix}-vnet",
    resource_group_name=resource_group.name,
    location=location,
    virtual_network_name=f"{resource_prefix}-vnet",
    address_space=azure_native.network.AddressSpaceArgs(
        address_prefixes=["10.0.0.0/16"]
    ),
    tags=tags
)

# AKS Subnet
aks_subnet = azure_native.network.Subnet(
    f"{resource_prefix}-aks-subnet",
    resource_group_name=resource_group.name,
    virtual_network_name=vnet.name,
    subnet_name="aks-subnet",
    address_prefix="10.0.1.0/24"
)

# PostgreSQL Subnet (with delegation)
postgres_subnet = azure_native.network.Subnet(
    f"{resource_prefix}-postgres-subnet",
    resource_group_name=resource_group.name,
    virtual_network_name=vnet.name,
    subnet_name="postgres-subnet",
    address_prefix="10.0.2.0/24",
    delegations=[azure_native.network.DelegationArgs(
        name="postgres-delegation",
        service_name="Microsoft.DBforPostgreSQL/flexibleServers"
    )]
)

# 3. Azure Container Registry
acr = azure_native.containerregistry.Registry(
    f"{resource_prefix}-acr",
    resource_group_name=resource_group.name,
    location=location,
    registry_name=f"{project_name}{environment}acr".replace("-", ""),
    sku=azure_native.containerregistry.SkuArgs(
        name="Basic"
    ),
    admin_user_enabled=True,
    tags=tags
)

# Get ACR credentials
acr_credentials = Output.all(resource_group.name, acr.name).apply(
    lambda args: azure_native.containerregistry.list_registry_credentials(
        resource_group_name=args[0],
        registry_name=args[1]
    )
)

# 4. Log Analytics Workspace
log_analytics = azure_native.operationalinsights.Workspace(
    f"{resource_prefix}-logs",
    resource_group_name=resource_group.name,
    location=location,
    workspace_name=f"{resource_prefix}-logs",
    sku=azure_native.operationalinsights.WorkspaceSkuArgs(
        name="PerGB2018"
    ),
    retention_in_days=30,
    tags=tags
)

# 5. Azure Kubernetes Service (AKS)
aks_cluster = azure_native.containerservice.ManagedCluster(
    f"{resource_prefix}-aks",
    resource_group_name=resource_group.name,
    location=location,
    resource_name=f"{resource_prefix}-aks",
    
    # Kubernetes Version
    kubernetes_version=k8s_version,
    dns_prefix=f"{resource_prefix}-aks",
    
    # Identity
    identity=azure_native.containerservice.ManagedClusterIdentityArgs(
        type="SystemAssigned"
    ),
    
    # Network Profile
    network_profile=azure_native.containerservice.ContainerServiceNetworkProfileArgs(
        network_plugin="azure",
        network_policy="azure",
        service_cidr="10.1.0.0/16",
        dns_service_ip="10.1.0.10",
        load_balancer_sku="standard"
    ),
    
    # Default Node Pool (System)
    agent_pool_profiles=[
        azure_native.containerservice.ManagedClusterAgentPoolProfileArgs(
            name="system",
            count=node_count,
            vm_size=node_vm_size,
            os_type="Linux",
            os_disk_size_gb=30,
            type="VirtualMachineScaleSets",
            mode="System",
            enable_auto_scaling=enable_autoscaling,
            min_count=min_node_count if enable_autoscaling else None,
            max_count=max_node_count if enable_autoscaling else None,
            vnet_subnet_id=aks_subnet.id,
            max_pods=50,
            enable_node_public_ip=False
        )
    ],
    
    # Add-ons
    addon_profiles={
        "omsagent": azure_native.containerservice.ManagedClusterAddonProfileArgs(
            enabled=enable_monitoring,
            config={
                "logAnalyticsWorkspaceResourceID": log_analytics.id
            }
        ),
        "azurepolicy": azure_native.containerservice.ManagedClusterAddonProfileArgs(
            enabled=True
        )
    },
    
    # Enable RBAC
    enable_rbac=True,
    
    # API Server Access Profile
    api_server_access_profile=azure_native.containerservice.ManagedClusterAPIServerAccessProfileArgs(
        enable_private_cluster=False  # Set to True for private cluster
    ),
    
    # Auto Scaler Profile
    auto_scaler_profile=azure_native.containerservice.ManagedClusterPropertiesAutoScalerProfileArgs(
        scale_down_delay_after_add="10m",
        scale_down_unneeded_time="10m",
        scan_interval="10s"
    ) if enable_autoscaling else None,
    
    tags=tags
)

# Get AKS credentials
aks_creds = Output.all(resource_group.name, aks_cluster.name).apply(
    lambda args: azure_native.containerservice.list_managed_cluster_user_credentials(
        resource_group_name=args[0],
        resource_name=args[1]
    )
)

# Decode kubeconfig
kubeconfig = aks_creds.apply(
    lambda creds: json.loads(creds.kubeconfigs[0].value.decode())
)

# 6. Kubernetes Provider
k8s_provider = k8s.Provider(
    f"{resource_prefix}-k8s-provider",
    kubeconfig=aks_creds.apply(
        lambda creds: creds.kubeconfigs[0].value.decode()
    )
)

# 7. Grant AKS access to ACR
acr_assignment = azure_native.authorization.RoleAssignment(
    f"{resource_prefix}-acr-role",
    principal_id=aks_cluster.identity_profile["kubeletidentity"].object_id,
    principal_type="ServicePrincipal",
    role_definition_id=f"/subscriptions/{azure_native.authorization.get_client_config().subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d",  # AcrPull
    scope=acr.id
)

# 8. Create Kubernetes Namespaces
namespaces = {}
for ns_name in ["opsverse", "monitoring", "istio-system"]:
    namespaces[ns_name] = k8s.core.v1.Namespace(
        ns_name,
        metadata=k8s.meta.v1.ObjectMetaArgs(
            name=ns_name,
            labels={"environment": environment}
        ),
        opts=pulumi.ResourceOptions(provider=k8s_provider)
    )

# 9. Install Istio (Service Mesh)
if enable_istio:
    # Istio Base
    istio_base = k8s.helm.v3.Release(
        "istio-base",
        k8s.helm.v3.ReleaseArgs(
            chart="base",
            version="1.20.0",
            namespace="istio-system",
            repository_opts=k8s.helm.v3.RepositoryOptsArgs(
                repo="https://istio-release.storage.googleapis.com/charts"
            ),
            skip_await=False
        ),
        opts=pulumi.ResourceOptions(
            provider=k8s_provider,
            depends_on=[namespaces["istio-system"]]
        )
    )
    
    # Istiod (Control Plane)
    istiod = k8s.helm.v3.Release(
        "istiod",
        k8s.helm.v3.ReleaseArgs(
            chart="istiod",
            version="1.20.0",
            namespace="istio-system",
            repository_opts=k8s.helm.v3.RepositoryOptsArgs(
                repo="https://istio-release.storage.googleapis.com/charts"
            ),
            values={
                "meshConfig": {
                    "accessLogFile": "/dev/stdout"
                }
            },
            skip_await=False
        ),
        opts=pulumi.ResourceOptions(
            provider=k8s_provider,
            depends_on=[istio_base]
        )
    )
    
    # Istio Ingress Gateway
    istio_ingress = k8s.helm.v3.Release(
        "istio-ingress",
        k8s.helm.v3.ReleaseArgs(
            chart="gateway",
            version="1.20.0",
            namespace="istio-system",
            repository_opts=k8s.helm.v3.RepositoryOptsArgs(
                repo="https://istio-release.storage.googleapis.com/charts"
            ),
            values={
                "service": {
                    "type": "LoadBalancer"
                }
            },
            skip_await=False
        ),
        opts=pulumi.ResourceOptions(
            provider=k8s_provider,
            depends_on=[istiod]
        )
    )

# 10. Create Docker Registry Secret
docker_secret = k8s.core.v1.Secret(
    "acr-secret",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name="acr-secret",
        namespace="opsverse"
    ),
    type="kubernetes.io/dockerconfigjson",
    string_data={
        ".dockerconfigjson": Output.all(
            acr.login_server,
            acr_credentials
        ).apply(lambda args: json.dumps({
            "auths": {
                args[0]: {
                    "username": args[1].username,
                    "password": args[1].passwords[0].value,
                    "auth": ""
                }
            }
        }))
    },
    opts=pulumi.ResourceOptions(
        provider=k8s_provider,
        depends_on=[namespaces["opsverse"]]
    )
)

# 11. PostgreSQL Flexible Server
postgres_password = config.require_secret("postgres_password")

postgres_server = azure_native.dbforpostgresql.Server(
    f"{resource_prefix}-postgres",
    resource_group_name=resource_group.name,
    location=location,
    server_name=f"{resource_prefix}-postgres",
    sku=azure_native.dbforpostgresql.SkuArgs(
        name="Standard_B1ms",
        tier="Burstable"
    ),
    storage=azure_native.dbforpostgresql.StorageArgs(
        storage_size_gb=32
    ),
    backup=azure_native.dbforpostgresql.BackupArgs(
        backup_retention_days=7,
        geo_redundant_backup="Disabled"
    ),
    network=azure_native.dbforpostgresql.NetworkArgs(
        delegated_subnet_resource_id=postgres_subnet.id,
        public_network_access="Disabled"
    ),
    version="15",
    administrator_login="opsverse_admin",
    administrator_login_password=postgres_password,
    tags=tags
)

# Create databases
databases = {}
for db_name in ["auth_service", "audit_logs", "opsverse"]:
    databases[db_name] = azure_native.dbforpostgresql.Database(
        f"{resource_prefix}-{db_name}-db",
        resource_group_name=resource_group.name,
        server_name=postgres_server.name,
        database_name=db_name,
        charset="UTF8",
        collation="en_US.utf8"
    )

# 12. Azure Cache for Redis
redis_cache = azure_native.cache.Redis(
    f"{resource_prefix}-redis",
    resource_group_name=resource_group.name,
    location=location,
    name=f"{resource_prefix}-redis",
    sku=azure_native.cache.SkuArgs(
        name="Basic",
        family="C",
        capacity=0
    ),
    enable_non_ssl_port=False,
    minimum_tls_version="1.2",
    redis_configuration=azure_native.cache.RedisCommonPropertiesRedisConfigurationArgs(
        maxmemory_policy="allkeys-lru"
    ),
    tags=tags
)

redis_keys = Output.all(resource_group.name, redis_cache.name).apply(
    lambda args: azure_native.cache.list_redis_keys(
        resource_group_name=args[0],
        name=args[1]
    )
)

# 13. Key Vault for Secrets
key_vault = azure_native.keyvault.Vault(
    f"{resource_prefix}-kv",
    resource_group_name=resource_group.name,
    location=location,
    vault_name=f"{project_name}-{environment}-kv"[:24],
    properties=azure_native.keyvault.VaultPropertiesArgs(
        tenant_id=azure_native.authorization.get_client_config().tenant_id,
        sku=azure_native.keyvault.SkuArgs(
            family="A",
            name="standard"
        ),
        access_policies=[],
        enabled_for_deployment=True,
        enabled_for_template_deployment=True,
        soft_delete_retention_in_days=7
    ),
    tags=tags
)

# 14. Create Kubernetes Secrets for Services
postgres_secret = k8s.core.v1.Secret(
    "postgres-secret",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name="postgres-secret",
        namespace="opsverse"
    ),
    string_data={
        "host": postgres_server.fully_qualified_domain_name,
        "username": pulumi.Output.from_input("opsverse_admin"),
        "password": postgres_password,
        "auth_db": pulumi.Output.from_input("auth_service"),
        "audit_db": pulumi.Output.from_input("audit_logs"),
        "main_db": pulumi.Output.from_input("opsverse")
    },
    opts=pulumi.ResourceOptions(
        provider=k8s_provider,
        depends_on=[namespaces["opsverse"]]
    )
)

redis_secret = k8s.core.v1.Secret(
    "redis-secret",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name="redis-secret",
        namespace="opsverse"
    ),
    string_data={
        "host": redis_cache.host_name,
        "password": redis_keys.apply(lambda keys: keys.primary_key)
    },
    opts=pulumi.ResourceOptions(
        provider=k8s_provider,
        depends_on=[namespaces["opsverse"]]
    )
)

# Get Ingress Gateway LoadBalancer IP
ingress_ip = None
if enable_istio:
    ingress_ip = k8s.core.v1.Service.get(
        "istio-ingress-service",
        pulumi.Output.concat(namespaces["istio-system"].metadata["name"], "/istio-ingress"),
        opts=pulumi.ResourceOptions(provider=k8s_provider)
    ).status.apply(lambda status: status.load_balancer.ingress[0].ip if status and status.load_balancer else None)

# Exports
export("resource_group_name", resource_group.name)
export("aks_cluster_name", aks_cluster.name)
export("aks_cluster_fqdn", aks_cluster.fqdn)
export("acr_login_server", acr.login_server)
export("acr_admin_username", acr_credentials.apply(lambda c: c.username))
export("postgres_server_fqdn", postgres_server.fully_qualified_domain_name)
export("redis_hostname", redis_cache.host_name)
export("key_vault_uri", key_vault.properties.apply(lambda p: p.vault_uri))
export("kubeconfig", aks_creds.apply(lambda creds: creds.kubeconfigs[0].value.decode()))
export("istio_ingress_ip", ingress_ip if enable_istio else "Istio not enabled")
export("opsverse_namespace", "opsverse")

# Export connection strings for services
export("postgres_connection_strings", {
    "auth_service": Output.all(
        postgres_server.fully_qualified_domain_name,
        postgres_password
    ).apply(lambda args: f"postgresql://opsverse_admin:{args[1]}@{args[0]}:5432/auth_service?sslmode=require"),
    "audit_logs": Output.all(
        postgres_server.fully_qualified_domain_name,
        postgres_password
    ).apply(lambda args: f"postgresql://opsverse_admin:{args[1]}@{args[0]}:5432/audit_logs?sslmode=require"),
    "opsverse": Output.all(
        postgres_server.fully_qualified_domain_name,
        postgres_password
    ).apply(lambda args: f"postgresql://opsverse_admin:{args[1]}@{args[0]}:5432/opsverse?sslmode=require")
})

export("redis_connection_string", Output.all(
    redis_cache.host_name,
    redis_keys
).apply(lambda args: f"rediss://:{args[1].primary_key}@{args[0]}:6380/0"))
