# Azure Infrastructure Unit Tests

This directory contains comprehensive unit tests for the Azure Infrastructure (Pulumi) configuration.

## Test Structure

The tests are organized into modular files for better maintainability:

- `conftest.py` - Shared pytest fixtures and test utilities
- `test_resource_group.py` - Resource group configuration tests
- `test_acr.py` - Azure Container Registry tests
- `test_network.py` - Virtual Network and Subnet tests
- `test_aks.py` - AKS cluster configuration tests
- `test_pulumi_config.py` - Pulumi configuration and exports tests

## Running Tests

### Run all tests:

```bash
cd /home/sam/git/azure-infrastructure
pytest unit-test/
```

### Run specific test file:

```bash
pytest unit-test/test_aks.py
```

### Run specific test class:

```bash
pytest unit-test/test_aks.py::TestAKSConfiguration
```

### Run specific test:

```bash
pytest unit-test/test_aks.py::TestAKSConfiguration::test_aks_cluster_naming
```

### Run Pulumi-specific tests:

```bash
pytest unit-test/ -m pulumi
```

### Run with coverage:

```bash
pytest unit-test/ --cov=infrastructure --cov-report=html
```

### Run with verbose output:

```bash
pytest unit-test/ -v
```

## Test Dependencies

Required packages (add to requirements.txt):

```
pytest==7.4.3
pytest-cov==4.1.0
pytest-mock==3.12.0
```

Note: Pulumi SDK is already in requirements.txt

## Testing Strategy

### Configuration Testing

Tests validate:

- Pulumi configuration values and defaults
- Environment-specific settings
- Resource naming conventions
- Network CIDR configurations
- Resource tags

### Resource Testing

Tests cover:

- **Resource Groups** - Naming, location, tagging
- **ACR** - Naming (alphanumeric only), SKU selection, admin settings
- **VNet** - Address space, subnet configuration, CIDR validation
- **AKS** - Kubernetes version, node configuration, autoscaling settings
- **Networking** - Service CIDR, DNS configuration, subnet relationships

### Validation Tests

- CIDR range validation using `ipaddress` module
- Subnet containment within VNet
- DNS IP within service CIDR
- Naming convention compliance
- Version string format validation

## Mocking Strategy

Tests use extensive mocking for:

- **Pulumi Config** - Mock configuration values
- **Azure Resources** - Mock resource creation and properties
- **Pulumi Outputs** - Mock output values and apply functions

## Network Testing

Network tests include:

- CIDR notation validation
- IPv4 address validation
- Subnet hierarchy verification
- Service network isolation

## AKS Testing

AKS tests cover:

- Cluster configuration
- Node pool settings
- Autoscaling parameters
- Kubernetes version validation
- Managed identity configuration

## Configuration Environments

Tests validate configurations for:

- Development (dev)
- Staging (staging)
- Production (production)

## Writing New Tests

When adding new tests:

1. Follow the existing modular structure
2. Use descriptive test names that explain what is being tested
3. Add shared fixtures to `conftest.py`
4. Group related tests into classes
5. Include docstrings for test classes and methods
6. Mock Pulumi resources and Azure SDK calls
7. Test both configuration validation and resource properties
8. Include edge cases and boundary conditions
9. Validate infrastructure as code best practices

## Important Notes

- These are unit tests for infrastructure code validation
- They do not create actual Azure resources
- They validate configuration logic and naming conventions
- Use Pulumi preview/up for actual infrastructure validation
- Integration tests should be separate and run against real Azure resources
