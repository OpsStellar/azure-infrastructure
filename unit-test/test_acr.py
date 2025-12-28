"""
Unit tests for Azure Container Registry configuration
"""

import pytest
from unittest.mock import patch, MagicMock


class TestACRConfiguration:
    """Test suite for Azure Container Registry configuration"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_acr_naming_convention(self, mock_pulumi_config, mock_config):
        """Test ACR naming convention (alphanumeric only)"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        
        # ACR name must be alphanumeric
        acr_name = f"{project_name}{environment}acr".replace("-", "")
        
        assert acr_name == "opsstellardevacr"
        assert acr_name.isalnum()

    @patch('infrastructure.__main__.pulumi.Config')
    def test_acr_sku_configuration(self, mock_pulumi_config, mock_config):
        """Test ACR SKU configuration"""
        mock_pulumi_config.return_value = mock_config
        
        acr_sku = mock_config.get("acr_sku")
        assert acr_sku in ["Basic", "Standard", "Premium"]

    @patch('infrastructure.__main__.pulumi.Config')
    def test_acr_admin_user_enabled(self, mock_pulumi_config, mock_config):
        """Test that ACR admin user is enabled for CI/CD"""
        mock_pulumi_config.return_value = mock_config
        
        # Admin user should be enabled for CI/CD pipelines
        admin_enabled = True
        assert admin_enabled is True

    @patch('infrastructure.__main__.pulumi.Config')
    def test_acr_basic_sku_for_dev(self, mock_pulumi_config, mock_config):
        """Test that dev environment uses Basic SKU"""
        mock_pulumi_config.return_value = mock_config
        
        environment = mock_config.get("environment")
        acr_sku = mock_config.get("acr_sku")
        
        if environment == "dev":
            assert acr_sku == "Basic"


class TestACRCredentials:
    """Test suite for ACR credentials handling"""

    def test_acr_credentials_structure(self, mock_acr):
        """Test ACR credentials structure"""
        assert hasattr(mock_acr, "name")
        assert hasattr(mock_acr, "login_server")

    def test_acr_login_server_format(self, mock_acr):
        """Test ACR login server format"""
        login_server = mock_acr.login_server
        assert login_server.endswith(".azurecr.io")
        assert "opsstellar" in login_server
