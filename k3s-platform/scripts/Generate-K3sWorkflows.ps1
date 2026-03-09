###############################################################################
# Generate-K3sWorkflows.ps1
# ---------------------------------------------------------------------------
# Reads the canonical template and stamps a deploy-k3s.yml into every service
# directory under the workspace root.
#
# Usage (run from the workspace root  d:\OS\git):
#   .\azure-infrastructure\k3s-platform\scripts\Generate-K3sWorkflows.ps1
#
# Optional: override the workspace root and/or template path
#   .\...ps1 -WorkspaceRoot "D:\OS\git" -Force
###############################################################################
param(
    [string]$WorkspaceRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path,
    [string]$TemplatePath  = "$PSScriptRoot\..\\.github\workflows\deploy-k3s-template.yml",
    [switch]$Force          # Overwrite if deploy-k3s.yml already exists
)

$ErrorActionPreference = "Stop"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Ok   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green  }
function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan   }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "[ERR]  $m" -ForegroundColor Red    }

# ── Services to process ───────────────────────────────────────────────────────
$services = @(
    "apm-agent",
    "apm-service",
    "audit-logs",
    "auth-service",
    "chatbot",
    "code-commit",
    "cost-service",
    "db-service",
    "devops-core",
    "dora-service",
    "frontend",
    "incident-service",
    "infrastructure-service",
    "logging-service",
    "metrics-collector",
    "microgenie",
    "postgres",
    "redis",
    "release-management",
    "security-service",
    "settings-service",
    "testing-services"
)

# ── Load template ─────────────────────────────────────────────────────────────
if (-not (Test-Path $TemplatePath)) {
    Write-Err "Template not found: $TemplatePath"
    exit 1
}
$template = Get-Content $TemplatePath -Raw
Write-Info "Template loaded: $TemplatePath"
Write-Info "Workspace root : $WorkspaceRoot"
Write-Host ""

$created = 0; $skipped = 0; $missing = 0

foreach ($svc in $services) {
    $serviceDir   = Join-Path $WorkspaceRoot $svc
    $workflowsDir = Join-Path $serviceDir ".github\workflows"
    $outputFile   = Join-Path $workflowsDir "deploy-k3s.yml"

    # Skip if the service directory does not exist
    if (-not (Test-Path $serviceDir)) {
        Write-Warn "$svc → directory not found, skipping."
        $missing++
        continue
    }

    # Skip if already exists and -Force not set
    if ((Test-Path $outputFile) -and -not $Force) {
        Write-Warn "$svc → deploy-k3s.yml already exists. Use -Force to overwrite."
        $skipped++
        continue
    }

    # Ensure .github/workflows exists
    New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null

    # Stamp the service name into the template
    $content = $template -replace "%%SERVICE_NAME%%", $svc

    # Write output
    Set-Content -Path $outputFile -Value $content -Encoding UTF8 -NoNewline
    Write-Ok "$svc → $outputFile"
    $created++
}

Write-Host ""
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Created : $created" -ForegroundColor Green
Write-Host "  Skipped : $skipped  -- add -Force flag to overwrite" -ForegroundColor Yellow
Write-Host "  Missing : $missing  -- service dirs not found"       -ForegroundColor DarkGray
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Commit and push the generated deploy-k3s.yml files."
Write-Host "  2. Add the following secrets to each repo (or at org level):"
Write-Host "       K3S_KUBECONFIG  -- run: k3s-platform/scripts/export-kubeconfig.sh VM_IP"
Write-Host "       ACR_NAME        -- opsstellardevacr"
Write-Host "       ACR_USERNAME    -- service-principal-app-id"
Write-Host "       ACR_PASSWORD    -- service-principal-password"
Write-Host "  3. Trigger manually:"
Write-Host "       gh workflow run deploy-k3s.yml --repo ORG/SERVICE"
