"""
Unit tests for Virtual Network configuration
"""

import pytest
from unittest.mock import patch, MagicMock
import ipaddress


class TestVNetConfiguration:
    """Test suite for Virtual Network configuration"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_vnet_naming_convention(self, mock_pulumi_config, mock_config):
        """Test VNet naming convention"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        expected_name = f"{project_name}-{environment}-vnet"
        
        assert expected_name == "opsstellar-dev-vnet"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_vnet_address_space(self, mock_pulumi_config, mock_config):
        """Test VNet address space configuration"""
        mock_pulumi_config.return_value = mock_config
        
        vnet_address_space = mock_config.get("vnet_address_space")
        assert vnet_address_space == "10.0.0.0/16"
        
        # Validate it's a valid CIDR
        network = ipaddress.ip_network(vnet_address_space)
        assert network.version == 4

    @patch('infrastructure.__main__.pulumi.Config')
    def test_vnet_address_space_size(self, mock_pulumi_config, mock_config):
        """Test VNet address space is large enough"""
        mock_pulumi_config.return_value = mock_config
        
        vnet_address_space = mock_config.get("vnet_address_space")
        network = ipaddress.ip_network(vnet_address_space)
        
        # /16 network should have sufficient addresses
        assert network.num_addresses == 65536


class TestSubnetConfiguration:
    """Test suite for Subnet configuration"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_aks_subnet_naming(self, mock_pulumi_config, mock_config):
        """Test AKS subnet naming convention"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        expected_name = f"{project_name}-{environment}-aks-subnet"
        
        assert expected_name == "opsstellar-dev-aks-subnet"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_aks_subnet_address_prefix(self, mock_pulumi_config, mock_config):
        """Test AKS subnet address prefix"""
        mock_pulumi_config.return_value = mock_config
        
        aks_subnet_prefix = mock_config.get("aks_subnet_prefix")
        assert aks_subnet_prefix == "10.0.0.0/20"
        
        # Validate it's a valid CIDR
        network = ipaddress.ip_network(aks_subnet_prefix)
        assert network.version == 4

    @patch('infrastructure.__main__.pulumi.Config')
    def test_subnet_within_vnet_range(self, mock_pulumi_config, mock_config):
        """Test that subnet is within VNet address range"""
        mock_pulumi_config.return_value = mock_config
        
        vnet_address_space = mock_config.get("vnet_address_space")
        aks_subnet_prefix = mock_config.get("aks_subnet_prefix")
        
        vnet_network = ipaddress.ip_network(vnet_address_space)
        subnet_network = ipaddress.ip_network(aks_subnet_prefix)
        
        # Subnet should be within VNet range
        assert subnet_network.subnet_of(vnet_network)


class TestNetworkConfiguration:
    """Test suite for network settings"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_service_cidr_configuration(self, mock_pulumi_config, mock_config):
        """Test Kubernetes service CIDR configuration"""
        mock_pulumi_config.return_value = mock_config
        
        service_cidr = mock_config.get("service_cidr")
        assert service_cidr == "10.1.0.0/16"
        
        # Should be a valid CIDR
        network = ipaddress.ip_network(service_cidr)
        assert network.version == 4

    @patch('infrastructure.__main__.pulumi.Config')
    def test_dns_service_ip_configuration(self, mock_pulumi_config, mock_config):
        """Test DNS service IP configuration"""
        mock_pulumi_config.return_value = mock_config
        
        dns_service_ip = mock_config.get("dns_service_ip")
        assert dns_service_ip == "10.1.0.10"
        
        # Should be a valid IP
        ip = ipaddress.ip_address(dns_service_ip)
        assert ip.version == 4

    @patch('infrastructure.__main__.pulumi.Config')
    def test_dns_ip_within_service_cidr(self, mock_pulumi_config, mock_config):
        """Test that DNS IP is within service CIDR"""
        mock_pulumi_config.return_value = mock_config
        
        service_cidr = mock_config.get("service_cidr")
        dns_service_ip = mock_config.get("dns_service_ip")
        
        service_network = ipaddress.ip_network(service_cidr)
        dns_ip = ipaddress.ip_address(dns_service_ip)
        
        # DNS IP should be within service CIDR
        assert dns_ip in service_network
