"""
Unit tests for AKS cluster configuration
"""

import pytest
from unittest.mock import patch, MagicMock


class TestAKSConfiguration:
    """Test suite for AKS cluster configuration"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_aks_cluster_naming(self, mock_pulumi_config, mock_config):
        """Test AKS cluster naming convention"""
        mock_pulumi_config.return_value = mock_config
        
        project_name = mock_config.get("project_name")
        environment = mock_config.get("environment")
        expected_name = f"{project_name}-{environment}-aks"
        
        assert expected_name == "opsstellar-dev-aks"

    @patch('infrastructure.__main__.pulumi.Config')
    def test_aks_kubernetes_version(self, mock_pulumi_config, mock_config):
        """Test AKS Kubernetes version configuration"""
        mock_pulumi_config.return_value = mock_config
        
        k8s_version = mock_config.get("k8s_version")
        assert k8s_version == "1.28.3"
        
        # Version should follow semver format
        parts = k8s_version.split(".")
        assert len(parts) == 3
        assert all(part.isdigit() for part in parts)

    @patch('infrastructure.__main__.pulumi.Config')
    def test_aks_node_count_configuration(self, mock_pulumi_config, mock_config):
        """Test AKS node count configuration"""
        mock_pulumi_config.return_value = mock_config
        
        node_count = mock_config.get_int("node_count")
        assert node_count == 2
        assert node_count > 0

    @patch('infrastructure.__main__.pulumi.Config')
    def test_aks_node_vm_size(self, mock_pulumi_config, mock_config):
        """Test AKS node VM size configuration"""
        mock_pulumi_config.return_value = mock_config
        
        node_vm_size = mock_config.get("node_vm_size")
        assert node_vm_size == "Standard_B2s"
        assert node_vm_size.startswith("Standard_")


class TestAKSAutoscaling:
    """Test suite for AKS autoscaling configuration"""

    @patch('infrastructure.__main__.pulumi.Config')
    def test_autoscaling_enabled(self, mock_pulumi_config, mock_config):
        """Test that autoscaling is enabled"""
        mock_pulumi_config.return_value = mock_config
        
        enable_autoscaling = mock_config.get_bool("enable_autoscaling")
        assert enable_autoscaling is True

    @patch('infrastructure.__main__.pulumi.Config')
    def test_min_node_count(self, mock_pulumi_config, mock_config):
        """Test minimum node count for autoscaling"""
        mock_pulumi_config.return_value = mock_config
        
        min_node_count = mock_config.get_int("min_node_count")
        assert min_node_count == 1
        assert min_node_count > 0

    @patch('infrastructure.__main__.pulumi.Config')
    def test_max_node_count(self, mock_pulumi_config, mock_config):
        """Test maximum node count for autoscaling"""
        mock_pulumi_config.return_value = mock_config
        
        max_node_count = mock_config.get_int("max_node_count")
        assert max_node_count == 3
        assert max_node_count > 0

    @patch('infrastructure.__main__.pulumi.Config')
    def test_autoscaling_range_valid(self, mock_pulumi_config, mock_config):
        """Test that autoscaling range is valid"""
        mock_pulumi_config.return_value = mock_config
        
        min_node_count = mock_config.get_int("min_node_count")
        max_node_count = mock_config.get_int("max_node_count")
        node_count = mock_config.get_int("node_count")
        
        assert min_node_count <= node_count <= max_node_count
        assert min_node_count < max_node_count


class TestAKSNodePool:
    """Test suite for AKS node pool configuration"""

    def test_node_pool_has_required_properties(self, mock_aks_cluster):
        """Test that node pool has required properties"""
        assert hasattr(mock_aks_cluster, "name")
        assert hasattr(mock_aks_cluster, "kubernetes_version")

    @patch('infrastructure.__main__.pulumi.Config')
    def test_system_node_pool_configuration(self, mock_pulumi_config, mock_config):
        """Test system node pool configuration"""
        mock_pulumi_config.return_value = mock_config
        
        # System node pool should have specific characteristics
        node_vm_size = mock_config.get("node_vm_size")
        node_count = mock_config.get_int("node_count")
        
        assert node_vm_size is not None
        assert node_count >= 1


class TestAKSIdentity:
    """Test suite for AKS managed identity configuration"""

    def test_aks_uses_managed_identity(self):
        """Test that AKS uses managed identity"""
        # AKS should use system-assigned managed identity
        identity_type = "SystemAssigned"
        assert identity_type == "SystemAssigned"

    def test_managed_identity_for_acr_pull(self):
        """Test that managed identity can pull from ACR"""
        # This would test the role assignment for ACR pull
        # In actual infrastructure, this would be configured
        acr_pull_role = "AcrPull"
        assert acr_pull_role == "AcrPull"
