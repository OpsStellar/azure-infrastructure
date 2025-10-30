"""
Pulumi Infrastructure as Code for OpsVerse SaaS on Azure Kubernetes Service (AKS)
Optimized for production with service mesh, service discovery, and multi-environment support
"""

import pulumi
import pulumi_azure_native as azure_native
import pulumi_kubernetes as k8s
from pulumi import Output, export

# Configuration
config = pulumi.Config()
location = config.get("location") or "eastus"
environment = config.get("environment") or "production"
project_name = "opsstellar"

# Kubernetes configuration
k8s_version = config.get("k8s_version") or "1.28.3"
node_count = config.get_int("node_count") or 2
node_vm_size = config.get("node_vm_size") or "Standard_B2s"
enable_istio = config.get_bool("enable_istio") or True
enable_autoscaling = config.get_bool("enable_autoscaling") or True
min_node_count = config.get_int("min_node_count") or 2
max_node_count = config.get_int("max_node_count") or 5

# Resource naming
resource_prefix = f"{project_name}-{environment}"

# Tags for all resources
tags = {
    "Project": "opsstellar",
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

# 2. Azure Container Registry (Basic SKU - $5/month)
acr = azure_native.containerregistry.Registry(
    f"{resource_prefix}-acr",
    resource_group_name=resource_group.name,
    location=location,
    registry_name=f"{project_name}{environment}acr".replace("-", ""),  # ACR name must be alphanumeric
    sku=azure_native.containerregistry.SkuArgs(
        name="Basic"  # Basic: $5/month, 10GB storage
    ),
    admin_user_enabled=True,  # Enable admin for GitHub Actions
    tags=tags
)

# Get ACR credentials
acr_credentials = pulumi.Output.all(resource_group.name, acr.name).apply(
    lambda args: azure_native.containerregistry.list_registry_credentials(
        resource_group_name=args[0],
        registry_name=args[1]
    )
)

# 3. Log Analytics Workspace (for monitoring)
log_analytics = azure_native.operationalinsights.Workspace(
    f"{resource_prefix}-logs",
    resource_group_name=resource_group.name,
    location=location,
    workspace_name=f"{resource_prefix}-logs",
    sku=azure_native.operationalinsights.WorkspaceSkuArgs(
        name="PerGB2018"  # Pay-as-you-go
    ),
    retention_in_days=30,  # Minimum retention
    tags=tags
)

# 4. Container Apps Environment
container_apps_env = azure_native.app.ManagedEnvironment(
    f"{resource_prefix}-env",
    resource_group_name=resource_group.name,
    location=location,
    managed_environment_name=f"{resource_prefix}-env",
    app_logs_configuration=azure_native.app.AppLogsConfigurationArgs(
        destination="log-analytics",
        log_analytics_configuration=azure_native.app.LogAnalyticsConfigurationArgs(
            customer_id=log_analytics.customer_id,
            shared_key=log_analytics.primary_shared_key
        )
    ),
    tags=tags
)

# 5. PostgreSQL Flexible Server (Burstable B1ms - $25/month)
# Create a subnet for PostgreSQL
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

postgres_subnet = azure_native.network.Subnet(
    f"{resource_prefix}-postgres-subnet",
    resource_group_name=resource_group.name,
    virtual_network_name=vnet.name,
    subnet_name=f"{resource_prefix}-postgres-subnet",
    address_prefix="10.0.1.0/24",
    delegations=[azure_native.network.DelegationArgs(
        name="postgres-delegation",
        service_name="Microsoft.DBforPostgreSQL/flexibleServers"
    )]
)

# PostgreSQL admin password from config
postgres_password = config.require_secret("postgres_password")

postgres_server = azure_native.dbforpostgresql.Server(
    f"{resource_prefix}-postgres",
    resource_group_name=resource_group.name,
    location=location,
    server_name=f"{resource_prefix}-postgres",
    sku=azure_native.dbforpostgresql.SkuArgs(
        name="Standard_B1ms",  # 1 vCore, 2GB RAM
        tier="Burstable"
    ),
    storage=azure_native.dbforpostgresql.StorageArgs(
        storage_size_gb=32  # 32GB storage
    ),
    backup=azure_native.dbforpostgresql.BackupArgs(
        backup_retention_days=7,  # 7-day backup retention
        geo_redundant_backup="Disabled"  # Disabled to save cost
    ),
    network=azure_native.dbforpostgresql.NetworkArgs(
        delegated_subnet_resource_id=postgres_subnet.id,
        public_network_access="Disabled"  # Private access only
    ),
    version="15",  # PostgreSQL 15
    administrator_login="opsverse_admin",
    administrator_login_password=postgres_password,
    tags=tags
)

# Create databases
auth_db = azure_native.dbforpostgresql.Database(
    f"{resource_prefix}-auth-db",
    resource_group_name=resource_group.name,
    server_name=postgres_server.name,
    database_name="auth_service",
    charset="UTF8",
    collation="en_US.utf8"
)

audit_db = azure_native.dbforpostgresql.Database(
    f"{resource_prefix}-audit-db",
    resource_group_name=resource_group.name,
    server_name=postgres_server.name,
    database_name="audit_logs",
    charset="UTF8",
    collation="en_US.utf8"
)

opsverse_db = azure_native.dbforpostgresql.Database(
    f"{resource_prefix}-main-db",
    resource_group_name=resource_group.name,
    server_name=postgres_server.name,
    database_name="opsverse",
    charset="UTF8",
    collation="en_US.utf8"
)

# 6. Azure Cache for Redis (Basic C0 - $16.80/month)
redis_cache = azure_native.cache.Redis(
    f"{resource_prefix}-redis",
    resource_group_name=resource_group.name,
    location=location,
    name=f"{resource_prefix}-redis",
    sku=azure_native.cache.SkuArgs(
        name="Basic",  # Basic tier
        family="C",
        capacity=0  # C0 - 250MB cache
    ),
    enable_non_ssl_port=False,  # Security best practice
    minimum_tls_version="1.2",
    redis_configuration=azure_native.cache.RedisCommonPropertiesRedisConfigurationArgs(
        maxmemory_policy="allkeys-lru"  # Eviction policy
    ),
    tags=tags
)

# Get Redis access keys
redis_keys = pulumi.Output.all(resource_group.name, redis_cache.name).apply(
    lambda args: azure_native.cache.list_redis_keys(
        resource_group_name=args[0],
        name=args[1]
    )
)

# 7. Key Vault for secrets
key_vault = azure_native.keyvault.Vault(
    f"{resource_prefix}-kv",
    resource_group_name=resource_group.name,
    location=location,
    vault_name=f"{project_name}-{environment}-kv"[:24],  # KV name max 24 chars
    properties=azure_native.keyvault.VaultPropertiesArgs(
        tenant_id=azure_native.authorization.get_client_config().tenant_id,
        sku=azure_native.keyvault.SkuArgs(
            family="A",
            name="standard"  # Standard tier
        ),
        access_policies=[],  # Will be configured via Azure AD
        enabled_for_deployment=True,
        enabled_for_template_deployment=True,
        soft_delete_retention_in_days=7  # Minimum for cost savings
    ),
    tags=tags
)

# 8. Container Apps

# Frontend Container App
frontend_app = azure_native.app.ContainerApp(
    f"{resource_prefix}-frontend",
    resource_group_name=resource_group.name,
    location=location,
    container_app_name=f"{resource_prefix}-frontend",
    managed_environment_id=container_apps_env.id,
    configuration=azure_native.app.ConfigurationArgs(
        ingress=azure_native.app.IngressArgs(
            external=True,
            target_port=80,
            transport="auto",
            allow_insecure=False
        ),
        registries=[azure_native.app.RegistryCredentialsArgs(
            server=acr.login_server,
            username=acr_credentials.apply(lambda c: c.username),
            password_secret_ref="acr-password"
        )],
        secrets=[
            azure_native.app.SecretArgs(
                name="acr-password",
                value=acr_credentials.apply(lambda c: c.passwords[0].value)
            )
        ]
    ),
    template=azure_native.app.TemplateArgs(
        containers=[azure_native.app.ContainerArgs(
            name="frontend",
            image=acr.login_server.apply(lambda s: f"{s}/opsverse-frontend:latest"),
            resources=azure_native.app.ContainerResourcesArgs(
                cpu=0.25,
                memory="0.5Gi"
            )
        )],
        scale=azure_native.app.ScaleArgs(
            min_replicas=0,  # Scale to zero when idle
            max_replicas=3,
            rules=[
                azure_native.app.ScaleRuleArgs(
                    name="http-rule",
                    http=azure_native.app.HttpScaleRuleArgs(
                        metadata={"concurrentRequests": "10"}
                    )
                )
            ]
        )
    ),
    tags=tags
)

# Auth Service Container App
auth_service_app = azure_native.app.ContainerApp(
    f"{resource_prefix}-auth-service",
    resource_group_name=resource_group.name,
    location=location,
    container_app_name=f"{resource_prefix}-auth-service",
    managed_environment_id=container_apps_env.id,
    configuration=azure_native.app.ConfigurationArgs(
        ingress=azure_native.app.IngressArgs(
            external=True,
            target_port=8001,
            transport="auto"
        ),
        registries=[azure_native.app.RegistryCredentialsArgs(
            server=acr.login_server,
            username=acr_credentials.apply(lambda c: c.username),
            password_secret_ref="acr-password"
        )],
        secrets=[
            azure_native.app.SecretArgs(
                name="acr-password",
                value=acr_credentials.apply(lambda c: c.passwords[0].value)
            ),
            azure_native.app.SecretArgs(
                name="database-url",
                value=Output.all(
                    postgres_server.name,
                    postgres_server.fully_qualified_domain_name,
                    postgres_password
                ).apply(lambda args: 
                    f"postgresql://opsverse_admin:{args[2]}@{args[1]}:5432/auth_service?sslmode=require"
                )
            ),
            azure_native.app.SecretArgs(
                name="redis-url",
                value=Output.all(
                    redis_cache.host_name,
                    redis_keys
                ).apply(lambda args:
                    f"rediss://:{args[1].primary_key}@{args[0]}:6380/0"
                )
            )
        ]
    ),
    template=azure_native.app.TemplateArgs(
        containers=[azure_native.app.ContainerArgs(
            name="auth-service",
            image=acr.login_server.apply(lambda s: f"{s}/opsverse-auth-service:latest"),
            resources=azure_native.app.ContainerResourcesArgs(
                cpu=0.5,
                memory="1Gi"
            ),
            env=[
                azure_native.app.EnvironmentVarArgs(
                    name="DATABASE_URL",
                    secret_ref="database-url"
                ),
                azure_native.app.EnvironmentVarArgs(
                    name="REDIS_URL",
                    secret_ref="redis-url"
                ),
                azure_native.app.EnvironmentVarArgs(
                    name="JWT_SECRET_KEY",
                    value=config.require_secret("jwt_secret_key")
                ),
                azure_native.app.EnvironmentVarArgs(
                    name="ENVIRONMENT",
                    value=environment
                )
            ]
        )],
        scale=azure_native.app.ScaleArgs(
            min_replicas=1,  # Always 1 replica for auth
            max_replicas=3
        )
    ),
    tags=tags
)

# Jenkins Dashboard Container App
jenkins_dashboard_app = azure_native.app.ContainerApp(
    f"{resource_prefix}-jenkins",
    resource_group_name=resource_group.name,
    location=location,
    container_app_name=f"{resource_prefix}-jenkins",
    managed_environment_id=container_apps_env.id,
    configuration=azure_native.app.ConfigurationArgs(
        ingress=azure_native.app.IngressArgs(
            external=True,
            target_port=8007,
            transport="auto"
        ),
        registries=[azure_native.app.RegistryCredentialsArgs(
            server=acr.login_server,
            username=acr_credentials.apply(lambda c: c.username),
            password_secret_ref="acr-password"
        )],
        secrets=[
            azure_native.app.SecretArgs(
                name="acr-password",
                value=acr_credentials.apply(lambda c: c.passwords[0].value)
            )
        ]
    ),
    template=azure_native.app.TemplateArgs(
        containers=[azure_native.app.ContainerArgs(
            name="jenkins-dashboard",
            image=acr.login_server.apply(lambda s: f"{s}/opsverse-jenkins-dashboard:latest"),
            resources=azure_native.app.ContainerResourcesArgs(
                cpu=0.25,
                memory="0.5Gi"
            ),
            env=[
                azure_native.app.EnvironmentVarArgs(
                    name="JENKINS_URL",
                    value=config.get("jenkins_url") or ""
                ),
                azure_native.app.EnvironmentVarArgs(
                    name="JENKINS_USERNAME",
                    value=config.get("jenkins_username") or ""
                ),
                azure_native.app.EnvironmentVarArgs(
                    name="JENKINS_API_TOKEN",
                    value=config.require_secret("jenkins_api_token")
                )
            ]
        )],
        scale=azure_native.app.ScaleArgs(
            min_replicas=0,
            max_replicas=2
        )
    ),
    tags=tags
)

# Exports
export("resource_group_name", resource_group.name)
export("acr_login_server", acr.login_server)
export("acr_admin_username", acr_credentials.apply(lambda c: c.username))
export("postgres_server_name", postgres_server.fully_qualified_domain_name)
export("redis_hostname", redis_cache.host_name)
export("frontend_url", frontend_app.configuration.apply(
    lambda c: f"https://{c.ingress.fqdn}" if c.ingress else "Not configured"
))
export("auth_service_url", auth_service_app.configuration.apply(
    lambda c: f"https://{c.ingress.fqdn}" if c.ingress else "Not configured"
))
export("jenkins_dashboard_url", jenkins_dashboard_app.configuration.apply(
    lambda c: f"https://{c.ingress.fqdn}" if c.ingress else "Not configured"
))
export("key_vault_uri", key_vault.properties.apply(lambda p: p.vault_uri))
