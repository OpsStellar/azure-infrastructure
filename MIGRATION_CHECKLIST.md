# Migration Checklist - New IaC Structure

## ✅ Completed Tasks

### Structure Changes

- [x] Created `infrastructure/` folder for Pulumi code
- [x] Moved `__main__.py` to `infrastructure/`
- [x] Moved `__main_aks.py` to `infrastructure/`
- [x] Stack config files kept at root (standard Pulumi convention)
  - [x] `Pulumi.dev.yaml` at root
  - [x] `Pulumi.staging.yaml` at root
  - [x] `Pulumi.production.yaml` at root

### Code Changes

- [x] Updated `infrastructure/__main__.py`:
  - [x] Removed Log Analytics Workspace
  - [x] Removed AKS monitoring addon
  - [x] Parameterized all configuration values
  - [x] Added support for environment-specific network ranges
  - [x] Added ACR SKU configuration
  - [x] Updated to read config from multiple sources
- [x] Updated `Pulumi.yaml`:
  - [x] Changed project name to `opsverse-azure`
  - [x] Added `main: infrastructure/` to specify code location
  - [x] Defined all configuration parameters with defaults
  - [x] Fixed `azure-native:location` to use `value` instead of `default`

### Workflow Changes

- [x] Rewrote `.github/workflows/provision-infrastructure.yml`:
  - [x] Simplified to single job
  - [x] Removed config copy step (files already at root)
  - [x] Added kubeconfig export and upload
  - [x] Removed unnecessary validation steps
  - [x] Made workflow cleaner and more maintainable

### Documentation

- [x] Created `README-STRUCTURE.md` with comprehensive guide
- [x] Created `STRUCTURE_SUMMARY.md` with quick reference
- [x] Created this migration checklist
- [x] Stack configs in root (standard Pulumi pattern)

### Testing

- [x] Verified `pulumi preview` works from root
- [x] Confirmed all 8 resources are planned correctly
- [x] Tested stack initialization
- [x] Stack configs work directly from root (no copy needed)

## 📋 What Changed

### Before

```
azure-infrastructure/
├── __main__.py (in root, with monitoring)
├── __main_aks.py (in root)
├── Pulumi.dev.yaml (in root)
├── Pulumi.staging.yaml (in root)
├── Pulumi.production.yaml (in root)
└── .github/workflows/provision-infrastructure.yml (complex, 247 lines)
```

### After

```
azure-infrastructure/
├── infrastructure/
│   ├── __main__.py (no monitoring, fully parameterized)
│   └── __main_aks.py
├── Pulumi.yaml (updated with main: infrastructure/)
├── Pulumi.dev.yaml (complete config at root)
├── Pulumi.staging.yaml (complete config at root)
├── Pulumi.production.yaml (complete config at root)
└── .github/workflows/provision-infrastructure.yml (simple, ~110 lines)
```

## 🚨 Breaking Changes

1. **Working Directory**: Pulumi runs from project root
2. **Config Files**: Stack configs are at root (standard Pulumi convention)
3. **GitHub Secrets**: Added `PULUMI_CONFIG_PASSPHRASE` requirement
4. **Monitoring**: Log Analytics and Container Insights completely removed
5. **Project Name**: Changed from `OpsStellar-saas-azure` to `opsverse-azure`

## 🔄 Migration Steps for Existing Deployments

If you have existing infrastructure:

1. **Backup current state**:

   ```bash
   pulumi stack export > backup-$(date +%Y%m%d).json
   ```

2. **Review changes**:

   ```bash
   # Stack configs already at root - no copying needed
   pulumi preview --diff
   ```

3. **Expect these changes**:

   - Log Analytics Workspace will be deleted
   - AKS monitoring addon will be disabled
   - No other infrastructure changes

4. **Apply if acceptable**:
   ```bash
   pulumi up
   ```

## ✅ Verification Steps

Run these to verify everything works:

```bash
# 1. Check structure
ls -la infrastructure/
ls -la Pulumi.*.yaml

# 2. Verify config
cat Pulumi.dev.yaml

# 3. Test local deployment
export PULUMI_CONFIG_PASSPHRASE="your-passphrase"
cp var/Pulumi.dev.yaml .
pulumi login --local
pulumi stack select dev || pulumi stack init dev
pulumi preview

# 4. Check GitHub Actions
# Push to a branch and create PR to test workflow
```

## 📝 Next Steps

1. Update GitHub repository secrets if needed
2. Test GitHub Actions workflow with manual dispatch
3. Update any documentation references to old structure
4. Train team on new structure and workflow
5. Consider adding:
   - Terraform migration guide (if applicable)
   - Cost estimation in workflow
   - Automated testing
   - Drift detection

## 🎉 Benefits Achieved

1. ✅ Clean separation of code and configuration
2. ✅ Environment-specific settings in dedicated files
3. ✅ Simplified GitHub Actions workflow
4. ✅ Cost optimization (no monitoring resources)
5. ✅ Easy local testing
6. ✅ Better maintainability
7. ✅ Clear documentation

---

**Date Completed**: October 31, 2025
**Tested**: ✅ Local preview successful
**Status**: Ready for deployment
