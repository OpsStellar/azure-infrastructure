# GitHub Actions Workflow - Manual Approval Setup

## 🎯 Workflow Overview

The workflow is optimized for **FREE GitHub accounts** with limited action minutes:

1. **Preview Job** - Shows what will change (runs for all actions)
2. **Manual Approval** - You review and approve/reject (no action minutes used during wait)
3. **Deploy Job** - Only runs if approved (saves minutes on rejected plans)

## 🔧 Required GitHub Setup

### Step 1: Create GitHub Environments

You need to create these environments in your repository:

1. Go to **Settings** → **Environments**
2. Create the following environments:

#### For Deployment Approval:

- `dev-approval`
- `staging-approval`
- `production-approval`

#### For Deployment:

- `dev`
- `staging`
- `production`

#### For Destroy:

- `dev-destroy`
- `staging-destroy`
- `production-destroy`

### Step 2: Configure Environment Protection Rules

For each `-approval` and `-destroy` environment:

1. Click on the environment name
2. Check **Required reviewers**
3. Add yourself (and team members) as reviewers
4. Optionally set **Wait timer** (e.g., 5 minutes to review)
5. Save protection rules

For regular environments (`dev`, `staging`, `production`):

- No protection rules needed (deployment happens after approval)
- Or add additional rules as needed

### Step 3: Set Repository Secrets

Go to **Settings** → **Secrets and variables** → **Actions**

Add these secrets:

```
ARM_CLIENT_ID              # Azure Service Principal Client ID
ARM_CLIENT_SECRET          # Azure Service Principal Secret
ARM_SUBSCRIPTION_ID        # Your Azure Subscription ID
ARM_TENANT_ID              # Azure Tenant ID
PULUMI_CONFIG_PASSPHRASE   # Passphrase for Pulumi secrets
```

## 📋 How to Use

### Option 1: Plan Only (Preview Changes)

1. Go to **Actions** → **Provision Azure Infrastructure**
2. Click **Run workflow**
3. Select:
   - **Environment**: `dev`, `staging`, or `production`
   - **Action**: `plan`
4. Click **Run workflow**
5. Review the preview output in the job summary
6. **No approval needed** - workflow stops after preview

### Option 2: Apply Changes (Deploy)

1. Go to **Actions** → **Provision Azure Infrastructure**
2. Click **Run workflow**
3. Select:
   - **Environment**: `dev`, `staging`, or `production`
   - **Action**: `apply`
4. Click **Run workflow**
5. **Preview Job** runs first - review the changes
6. **Approve Job** waits for your manual approval:
   - Go to the workflow run
   - You'll see "Waiting for approval"
   - Click **Review deployments**
   - Select the environment
   - Click **Approve and deploy** or **Reject**
7. If approved, **Deploy Job** runs and provisions infrastructure
8. If rejected, workflow stops (saves action minutes!)

### Option 3: Destroy Infrastructure

1. Go to **Actions** → **Provision Azure Infrastructure**
2. Click **Run workflow**
3. Select:
   - **Environment**: `dev`, `staging`, or `production`
   - **Action**: `destroy`
4. Click **Run workflow**
5. Preview of destroy is shown
6. Manual approval required (via `{env}-destroy` environment)
7. If approved, infrastructure is destroyed

## ⏱️ Action Minutes Optimization

### Before (Old Workflow):

- Setup: ~1 minute
- Preview: ~2 minutes
- Deploy: ~10 minutes
- **Total per run: ~13 minutes**
- **Rejected changes still used 13 minutes!**

### After (New Workflow):

#### Plan Only:

- Setup: ~1 minute
- Preview: ~2 minutes
- **Total: ~3 minutes**

#### Apply (Approved):

- Preview job: ~3 minutes
- **Wait for approval: 0 minutes (manual review)**
- Deploy job: ~11 minutes
- **Total: ~14 minutes**

#### Apply (Rejected):

- Preview job: ~3 minutes
- **Stopped at approval: No deploy job runs**
- **Total: ~3 minutes (saved ~11 minutes!)**

### Key Savings:

- ✅ Plan-only runs are fast (~3 min vs ~13 min)
- ✅ Rejected deployments don't waste minutes on deployment
- ✅ Review time doesn't count against action minutes
- ✅ No accidental deployments

## 🔒 Safety Features

1. **Manual Review Required**: No automatic deployments
2. **Preview First**: Always see what will change
3. **Separate Approval Steps**: Different approvals for deploy vs destroy
4. **Environment Protection**: GitHub's built-in protection rules
5. **Audit Trail**: All approvals logged in GitHub

## 📊 Workflow Jobs

```
┌─────────────────┐
│  Preview Job    │  Always runs, shows changes
└────────┬────────┘
         │
         ├─── If action = "plan" ──→ STOP (saves minutes)
         │
         ├─── If action = "apply"
         │      ↓
         │  ┌────────────────────┐
         │  │  Approve Job       │  Waits for manual approval
         │  │  (uses 0 minutes)  │  (no compute running)
         │  └─────────┬──────────┘
         │            │
         │            ├─── Approved ──→ Deploy Job (provisions)
         │            │
         │            └─── Rejected ──→ STOP (saves minutes!)
         │
         └─── If action = "destroy"
                ↓
            ┌──────────────────┐
            │  Destroy Job     │  Waits for approval, then destroys
            └──────────────────┘
```

## 🎯 Best Practices

1. **Always run "plan" first** to understand changes
2. **Review the preview carefully** before approving
3. **Use dev environment** for testing
4. **Require multiple approvers** for production
5. **Set wait timers** to prevent hasty approvals
6. **Check action minutes usage** in Settings → Billing

## 📝 Example Workflow Run

### Scenario: Deploy to Dev

1. **Start**: Click "Run workflow" → Environment: `dev`, Action: `apply`

2. **Preview Job** (2-3 minutes):

   ```
   ✅ Checkout code
   ✅ Setup Python
   ✅ Install dependencies
   ✅ Pulumi preview
   📋 Preview output saved to artifacts
   ```

3. **Waiting for Approval** (0 minutes of compute):

   ```
   ⏸️  Approval required for: dev-approval
   👤 Reviewers: @yourname
   📝 Review the preview output above
   ```

4. **Your Action**:

   - Click "Review deployments"
   - Read the changes
   - Decision: Approve ✅ or Reject ❌

5. **If Approved - Deploy Job** (10-12 minutes):

   ```
   ✅ Checkout code
   ✅ Setup Python
   ✅ Install dependencies
   ✅ Pulumi up
   ✅ Export outputs
   ✅ Upload kubeconfig
   ```

6. **If Rejected** (0 additional minutes):
   ```
   ❌ Deployment cancelled
   💰 Saved ~11 action minutes!
   ```

## 🚨 Troubleshooting

### "Environment not found"

→ Create the environment in Settings → Environments

### "No reviewers configured"

→ Add required reviewers in environment protection rules

### "Approval not appearing"

→ Refresh the page, check the "Review deployments" button

### "Action minutes exceeded"

→ Check Settings → Billing, consider upgrading or optimizing runs

## 📚 Additional Resources

- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments)
- [GitHub Actions Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions)
- [Environment Protection Rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-protection-rules)
