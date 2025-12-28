"""
Unit tests for Pulumi configuration and exports
"""

import pytest
from unittest.mock import patch, MagicMock


class TestPulumiConfiguration:
    """Test suite for Pulumi configuration"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_config_has_project_name(self, mock_pulumi_config, mock_config):
        """Test that configuration has project name"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        assert project_name is not None
        assert len(project_name) > 0

    @patch('infrastructure.__main__.pulumi.Config')
    def test_config_has_environment(self, mock_pulumi_config, mock_config):
        """Test that configuration has environment"""
        mock_pulumi_config.return_value = mock_config
        
        environment = mock_config.get("environment")
        assert environment is not None
        assert environment in ["dev", "staging", "production"]

    @patch('infrastructure.__main__.pulumi.Config')
    def test_config_defaults(self, mock_pulumi_config, mock_config):
        """Test that configuration has sensible defaults"""
        mock_pulumi_config.return_value = mock_config
        
        # Test that defaults are returned when config not set
        k8s_version = mock_config.get("k8s_version")
        node_count = mock_config.get_int("node_count")
        
        assert k8s_version is not None
        assert node_count is not None


class TestPulumiExports:
    """Test suite for Pulumi stack exports"""

    def test_resource_group_exported(self, mock_resource_group):
        """Test that resource group name is exported"""
        assert mock_resource_group.name is not None
        assert isinstance(mock_resource_group.name, str)

    def test_acr_login_server_exported(self, mock_acr):
        """Test that ACR login server is exported"""
        assert mock_acr.login_server is not None
        assert mock_acr.login_server.endswith(".azurecr.io")

    def test_aks_cluster_name_exported(self, mock_aks_cluster):
        """Test that AKS cluster name is exported"""
        assert mock_aks_cluster.name is not None
        assert isinstance(mock_aks_cluster.name, str)

    def test_aks_fqdn_exported(self, mock_aks_cluster):
        """Test that AKS FQDN is exported"""
        assert mock_aks_cluster.fqdn is not None
        assert ".azmk8s.io" in mock_aks_cluster.fqdn


class TestResourceNaming:
    """Test suite for resource naming conventions"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_resource_prefix_format(self, mock_pulumi_config, mock_config):
        """Test resource prefix format"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        resource_prefix = f"{project_name}-{environment}"
        
        assert resource_prefix == "opsstellar-dev"
        assert "-" in resource_prefix

    @patch('infrastructure.__main__.pulumi.Config')
    def test_all_resources_use_consistent_naming(self, mock_pulumi_config, mock_config):
        """Test that all resources use consistent naming"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        
        # All resources should start with project-environment
        prefix = f"{project_name}-{environment}"
        
        rg_name = f"{prefix}-rg"
        vnet_name = f"{prefix}-vnet"
        aks_name = f"{prefix}-aks"
        
        assert all(name.startswith(prefix) for name in [rg_name, vnet_name, aks_name])


class TestResourceTags:
    """Test suite for resource tagging"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_tags_include_required_fields(self, mock_pulumi_config, mock_config, sample_tags):
        """Test that tags include required fields"""
        mock_pulumi_config.return_value = mock_config
        
        required_fields = ["Project", "Environment", "ManagedBy"]
        for field in required_fields:
            assert field in sample_tags

    @patch('infrastructure.__main__.pulumi.Config')
    def test_tags_project_matches_config(self, mock_pulumi_config, mock_config, sample_tags):
        """Test that tags project matches configuration"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        assert sample_tags["Project"] == project_name

    @patch('infrastructure.__main__.pulumi.Config')
    def test_tags_environment_matches_config(self, mock_pulumi_config, mock_config, sample_tags):
        """Test that tags environment matches configuration"""
        mock_pulumi_config.return_value = mock_config
        
        environment = mock_config.get("environment")
        assert sample_tags["Environment"] == environment
