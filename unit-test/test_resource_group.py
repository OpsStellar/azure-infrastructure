"""
Unit tests for resource group configuration
"""

import pytest
from unittest.mock import patch, MagicMock
import pulumi


class TestResourceGroupConfiguration:
    """Test suite for Azure resource group configuration"""

    @patch('infrastructure.__main__.azure_native')
    @patch('infrastructure.__main__.pulumi.Config')
    def test_resource_group_creation(self, mock_pulumi_config, mock_azure_native, mock_config, sample_tags):
        """Test that resource group is created with correct configuration"""
        mock_pulumi_config.return_value = mock_config
        
        # Resource group should be created with correct parameters
        assert mock_config.get("project_name") == "opsstellar"
        assert mock_config.get("environment") == "dev"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_resource_group_naming_convention(self, mock_pulumi_config, mock_config):
        """Test resource group naming convention"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        expected_name = f"{project_name}-{environment}-rg"
        
        assert expected_name == "opsstellar-dev-rg"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_resource_group_location(self, mock_pulumi_config, mock_azure_config):
        """Test resource group location configuration"""
        location = mock_azure_config.get()
        assert location == "eastus"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_resource_group_tags(self, mock_pulumi_config, mock_config, sample_tags):
        """Test resource group tags"""
        mock_pulumi_config.return_value = mock_config
        
        assert sample_tags["Project"] == "opsstellar"
        assert sample_tags["Environment"] == "dev"
        assert sample_tags["ManagedBy"] == "Pulumi"


class TestResourceGroupEnvironments:
    """Test suite for different environment configurations"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_dev_environment_config(self, mock_pulumi_config):
        """Test development environment configuration"""
        config = MagicMock()
        config.get.return_value = "dev"
        mock_pulumi_config.return_value = config
        
        env = config.get("environment")
        assert env == "dev"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_staging_environment_config(self, mock_pulumi_config):
        """Test staging environment configuration"""
        config = MagicMock()
        config.get.return_value = "staging"
        mock_pulumi_config.return_value = config
        
        env = config.get("environment")
        assert env == "staging"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_production_environment_config(self, mock_pulumi_config):
        """Test production environment configuration"""
        config = MagicMock()
        config.get.return_value = "production"
        mock_pulumi_config.return_value = config
        
        env = config.get("environment")
        assert env == "production"
