"""
Shared pytest fixtures for Azure Infrastructure tests
"""

import pytest
from unittest.mock import Mock, MagicMock, patch
import pulumi


@pytest.fixture
def mock_config():
    """Mock Pulumi configuration"""
    config = MagicMock()
    config.get.side_effect = lambda key, default=None: {
        "project_name": "opsstellar",
        "environment": "dev",
        "location": "eastus",
        "k8s_version": "1.28.3",
        "node_count": 2,
        "node_vm_size": "Standard_B2s",
        "enable_autoscaling": True,
        "min_node_count": 1,
        "max_node_count": 3,
        "vnet_address_space": "10.0.0.0/16",
        "aks_subnet_prefix": "10.0.0.0/20",
        "service_cidr": "10.1.0.0/16",
        "dns_service_ip": "10.1.0.10",
        "acr_sku": "Basic"
    }.get(key, default)
    
    config.get_int.side_effect = lambda key, default=None: {
        "node_count": 2,
        "min_node_count": 1,
        "max_node_count": 3
    }.get(key, default)
    
    config.get_bool.side_effect = lambda key: {
        "enable_autoscaling": True
    }.get(key, None)
    
    return config


@pytest.fixture
def mock_azure_config():
    """Mock Azure-specific configuration"""
    config = MagicMock()
    config.get.return_value = "eastus"
    return config


@pytest.fixture
def mock_resource_group():
    """Mock Azure resource group"""
    rg = Mock()
    rg.name = "opsstellar-dev-rg"
    rg.location = "eastus"
    rg.id = "/subscriptions/sub-123/resourceGroups/opsstellar-dev-rg"
    return rg


@pytest.fixture
def mock_acr():
    """Mock Azure Container Registry"""
    acr = Mock()
    acr.name = "opsstellardevacr"
    acr.login_server = "opsstellardevacr.azurecr.io"
    acr.id = "/subscriptions/sub-123/resourceGroups/opsstellar-dev-rg/providers/Microsoft.ContainerRegistry/registries/opsstellardevacr"
    return acr


@pytest.fixture
def mock_vnet():
    """Mock Azure Virtual Network"""
    vnet = Mock()
    vnet.name = "opsstellar-dev-vnet"
    vnet.id = "/subscriptions/sub-123/resourceGroups/opsstellar-dev-rg/providers/Microsoft.Network/virtualNetworks/opsstellar-dev-vnet"
    vnet.address_space = Mock(address_prefixes=["10.0.0.0/16"])
    return vnet


@pytest.fixture
def mock_subnet():
    """Mock Azure Subnet"""
    subnet = Mock()
    subnet.name = "opsstellar-dev-aks-subnet"
    subnet.id = "/subscriptions/sub-123/resourceGroups/opsstellar-dev-rg/providers/Microsoft.Network/virtualNetworks/opsstellar-dev-vnet/subnets/opsstellar-dev-aks-subnet"
    subnet.address_prefix = "10.0.0.0/20"
    return subnet


@pytest.fixture
def mock_aks_cluster():
    """Mock AKS cluster"""
    cluster = Mock()
    cluster.name = "opsstellar-dev-aks"
    cluster.id = "/subscriptions/sub-123/resourceGroups/opsstellar-dev-rg/providers/Microsoft.ContainerService/managedClusters/opsstellar-dev-aks"
    cluster.fqdn = "opsstellar-dev-aks-dns-12345.hcp.eastus.azmk8s.io"
    cluster.kubernetes_version = "1.28.3"
    return cluster


@pytest.fixture
def mock_pulumi_output():
    """Mock Pulumi Output"""
    def create_output(value):
        output = MagicMock()
        output.apply = lambda fn: create_output(fn(value))
        return value
    return create_output


@pytest.fixture
def sample_tags():
    """Sample tags for Azure resources"""
    return {
        "Project": "opsstellar",
        "Environment": "dev",
        "ManagedBy": "Pulumi"
    }


@pytest.fixture
def mock_kubernetes_provider():
    """Mock Kubernetes provider"""
    provider = Mock()
    provider.id = "kubernetes-provider-123"
    return provider


@pytest.fixture
def mock_aks_credentials():
    """Mock AKS credentials"""
    return {
        "kubeconfigs": [{
            "value": "fake-kubeconfig-data-base64-encoded"
        }]
    }
