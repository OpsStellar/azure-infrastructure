<!-- .github/copilot-instructions.md
     Purpose: Short, project-specific guidance for AI code agents editing this repo.
     Keep concise (20-50 lines). Refer to concrete files and examples only.
--> 

# Copilot / AI Agent Instructions — Azure Infrastructure (Pulumi)

Quick orientation
- This repository defines Azure infrastructure for OpsStellar SaaS using Pulumi (Python).
- Two Pulumi entrypoints are present:
  - `__main__.py` — Container Apps focused program (Container Apps environment, cheaper/scale-to-zero).
  - `__main_aks.py` — AKS-focused program (AKS + Istio, for production/service-mesh use).
- CI/CD: see `.github/workflows/provision-infrastructure.yml` which runs Pulumi locally in GitHub Actions and exports useful outputs (kubeconfig, acr server).

What to change and how
- When modifying resources, update the matching Pulumi program (`__main__.py` or `__main_aks.py`).
- Naming and conventions:
  - resource prefix is computed as `f"{project_name}-{environment}"` (see both mains). Use this pattern when adding new resources.
  - ACR names are sanitized to alphanumeric in code (see `registry_name=...replace("-", "")`). Keep that constraint.
  - Tags are defined uniformly in `tags` dict; attach new resources to the same `tags` for consistency.
- Secrets and config:
  - Secrets are set via `pulumi config set --secret <name> <value>` (see `setup.sh` and README). Do not hardcode secrets.
  - Pulumi outputs commonly used: `acr_login_server`, `frontend_url`, `auth_service_url`, `kubeconfig`, `postgres_connection_strings`.

Developer workflows (specific commands)
- Local dev / bootstrap (from repo root):
  - Create venv, install deps: `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`
  - Login: `az login` and `pulumi login` (or `pulumi login --local` for local backend)
  - Create/select stack: `pulumi stack init production` or `pulumi stack select <env>`
  - Set secrets: `pulumi config set --secret postgres_password "..."` and `pulumi config set --secret jwt_secret_key "..."`
  - Preview/deploy: `pulumi preview` / `pulumi up`

CI/CICD specifics
- The GitHub workflow uses Azure service principal secrets (ARM_* env vars) and runs `pulumi login --local`.
- The workflow exports `kubeconfig`, `acr_login_server` and `cluster_fqdn` to artifacts — use those outputs when scripting service deployments.

Patterns to preserve
- Scale-to-zero policy is applied for Container Apps (min_replicas=0) — prefer this for cost-sensitive services unless auth/stateful.
- Private-by-default DB networking: PostgreSQL is created on a delegated subnet and public access disabled. Keep DB networking changes explicit and deliberate.
- When adding Kubernetes resources in `__main_aks.py`, use the `k8s.Provider` created from the exported kubeconfig.

Files to inspect for concrete examples
- `README.md` — deployment, costs, and quick start (canonical developer commands).
- `setup.sh` — interactive bootstrap that mirrors required local steps and pulumi config keys.
- `__main__.py`, `__main_aks.py` — the Pulumi programs (source of truth for resource shapes, outputs, secrets usage).
- `.github/workflows/provision-infrastructure.yml` — CI workflow and secrets required by Actions.
- `requirements.txt` — precise Pulumi Python dependency versions (don't upgrade without testing).

Editing rules for AI
- Make the minimal Pulumi change required. Keep naming, tagging, and secret handling consistent.
- When adding new outputs, document them in `README.md` if they will be consumed by downstream scripts/workflows.
- Do not add plaintext secrets or credentials to the repo. Use Pulumi config or GitHub Secrets.

If unsure, ask the human: "Should changes target Container Apps (`__main__.py`) or AKS (`__main_aks.py`) environment?"

End of instructions.

