# Quick Reference - GitHub Actions Workflow

## 🚀 How to Deploy

### 1. Preview Changes (No Deployment)

```
Actions → Run workflow
├─ Environment: dev/staging/production
└─ Action: plan
Result: See changes, nothing deployed (~3 min)
```

### 2. Deploy with Approval

```
Actions → Run workflow
├─ Environment: dev/staging/production
└─ Action: apply

Flow:
1. Preview runs (~3 min)
2. Manual approval required (0 min - you review)
3. ✅ Approve → Deploy (~11 min)
   ❌ Reject → Stop (saves ~11 min)
```

### 3. Destroy Infrastructure

```
Actions → Run workflow
├─ Environment: dev/staging/production
└─ Action: destroy

Flow:
1. Preview destroy
2. Manual approval required
3. ✅ Approve → Destroy
   ❌ Reject → Stop
```

## 🔧 Required Setup (One-Time)

### Create Environments in GitHub

Settings → Environments → New environment

**Create these 9 environments:**

```
✅ dev                → Regular deployment
✅ dev-approval       → Approval gate (add reviewers)
✅ dev-destroy        → Destroy approval (add reviewers)

✅ staging            → Regular deployment
✅ staging-approval   → Approval gate (add reviewers)
✅ staging-destroy    → Destroy approval (add reviewers)

✅ production         → Regular deployment
✅ production-approval → Approval gate (add reviewers)
✅ production-destroy  → Destroy approval (add reviewers)
```

### Add Required Reviewers

For each `-approval` and `-destroy` environment:

1. Click environment name
2. Check "Required reviewers"
3. Add yourself and team
4. Save

### Add Secrets

Settings → Secrets and variables → Actions

```
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_SUBSCRIPTION_ID
ARM_TENANT_ID
PULUMI_CONFIG_PASSPHRASE
```

## ⏱️ Action Minutes Usage

| Action                 | Preview | Approval | Deploy | Total        |
| ---------------------- | ------- | -------- | ------ | ------------ |
| **plan**               | 3 min   | -        | -      | **3 min**    |
| **apply (approved)**   | 3 min   | 0 min    | 11 min | **14 min**   |
| **apply (rejected)**   | 3 min   | 0 min    | -      | **3 min** ✅ |
| **destroy (approved)** | 3 min   | 0 min    | 8 min  | **11 min**   |

**Benefit**: Rejected plans save ~11 action minutes each!

## 🔒 Safety Checklist

- [x] Preview shows all changes before deployment
- [x] Manual approval required (no auto-deploy)
- [x] Separate approval for destroy operations
- [x] Audit trail of all approvals
- [x] Can reject without wasting action minutes

## 📱 Approval Process

1. Go to Actions → Running workflow
2. See "Waiting for approval" badge
3. Click "Review deployments"
4. Review the preview output
5. Select environment checkbox
6. Click "Approve and deploy" or "Reject"

## 💡 Pro Tips

✅ Always run `plan` first to understand changes
✅ Use `dev` for testing new infrastructure changes
✅ Add multiple reviewers for `production`
✅ Set wait timer (e.g., 5 min) to prevent hasty approvals
✅ Check preview output before approving
✅ Reject if anything looks unexpected

## 🆘 Quick Troubleshooting

| Problem                 | Solution                                         |
| ----------------------- | ------------------------------------------------ |
| "Environment not found" | Create environment in Settings → Environments    |
| "No approval button"    | Add required reviewers to environment            |
| "Workflow stuck"        | Refresh page, check Review deployments button    |
| "Minutes exceeded"      | Check Settings → Billing, optimize workflow runs |

## 📊 Workflow Status Icons

🟢 **Running** - Job in progress
🟡 **Waiting** - Pending approval (0 minutes used)
✅ **Success** - Completed successfully
❌ **Cancelled** - Rejected or stopped
🔴 **Failed** - Error occurred

## 📁 Artifacts

After each run, download:

- `preview-{env}-{run}` - Preview output
- `kubeconfig-{env}` - Kubernetes config (if deployed)

Location: Workflow run → Artifacts section

---

**Quick Start**: Create environments → Add reviewers → Add secrets → Run workflow with `plan`
