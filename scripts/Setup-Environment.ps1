<#
.SYNOPSIS
    Setup script for Azure infrastructure deployment environment.

.DESCRIPTION
    This script sets up the Python virtual environment and verifies all prerequisites
    for deploying Azure infrastructure with Pulumi.

.EXAMPLE
    .\Setup-Environment.ps1
    # Sets up the environment

.NOTES
    Author: OpsStellar Team
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OpsStellar Environment Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check Python
Write-Host "Checking Python..." -ForegroundColor Yellow
$pythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
}
elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
}

if (-not $pythonCmd) {
    Write-Host "❌ ERROR: Python not found. Please install Python 3.8 or higher." -ForegroundColor Red
    exit 1
}

$pythonVersion = & $pythonCmd --version 2>&1
Write-Host "✅ Found $pythonVersion" -ForegroundColor Green

# Create virtual environment
Push-Location $ProjectRoot
try {
    if (-not (Test-Path "venv")) {
        Write-Host ""
        Write-Host "Creating virtual environment..." -ForegroundColor Yellow
        & $pythonCmd -m venv venv
        Write-Host "✅ Virtual environment created" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Virtual environment already exists" -ForegroundColor Green
    }

    # Activate virtual environment
    Write-Host ""
    Write-Host "Activating virtual environment..." -ForegroundColor Yellow
    $activateScript = Join-Path $ProjectRoot "venv\Scripts\Activate.ps1"
    if (Test-Path $activateScript) {
        . $activateScript
        Write-Host "✅ Virtual environment activated" -ForegroundColor Green
    }

    # Upgrade pip
    Write-Host ""
    Write-Host "Upgrading pip..." -ForegroundColor Yellow
    pip install --upgrade pip --quiet
    Write-Host "✅ pip upgraded" -ForegroundColor Green

    # Install requirements
    if (Test-Path "requirements.txt") {
        Write-Host ""
        Write-Host "Installing dependencies..." -ForegroundColor Yellow
        pip install -r requirements.txt
        Write-Host "✅ Dependencies installed" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  WARNING: requirements.txt not found" -ForegroundColor Yellow
    }

    # Check for .env file
    Write-Host ""
    $envFile = Join-Path $ProjectRoot ".env"
    $envExample = Join-Path $ProjectRoot ".env.example"
    
    if (-not (Test-Path $envFile)) {
        Write-Host "⚠️  WARNING: .env file not found" -ForegroundColor Yellow
        if (Test-Path $envExample) {
            Write-Host "   Create it from the template:" -ForegroundColor Yellow
            Write-Host "   Copy-Item .env.example .env" -ForegroundColor White
            Write-Host "   notepad .env  # Fill in your credentials" -ForegroundColor White
        }
    }
    else {
        Write-Host "✅ .env file found" -ForegroundColor Green
    }

    # Check other prerequisites
    Write-Host ""
    Write-Host "Checking other prerequisites..." -ForegroundColor Yellow
    
    $tools = @(
        @{ Name = "Azure CLI"; Command = "az"; Install = "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" }
        @{ Name = "Pulumi"; Command = "pulumi"; Install = "https://www.pulumi.com/docs/install/" }
        @{ Name = "Helm"; Command = "helm"; Install = "https://helm.sh/docs/intro/install/" }
        @{ Name = "kubectl"; Command = "kubectl"; Install = "https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" }
    )

    foreach ($tool in $tools) {
        if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
            Write-Host "✅ $($tool.Name) is installed" -ForegroundColor Green
        }
        else {
            Write-Host "❌ $($tool.Name) is NOT installed" -ForegroundColor Red
            Write-Host "   Install: $($tool.Install)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Setup Complete!" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Create .env:     Copy-Item .env.example .env" -ForegroundColor Gray
    Write-Host "  2. Edit .env:       notepad .env" -ForegroundColor Gray
    Write-Host "  3. Provision:       .\Deploy-Azure.ps1 -Action provision -Environment dev" -ForegroundColor Gray
    Write-Host "  4. Deploy:          .\Deploy-Azure.ps1 -Action deploy -Environment dev" -ForegroundColor Gray
    Write-Host "  5. Or both:         .\Deploy-Azure.ps1 -Action all -Environment dev" -ForegroundColor Gray
    Write-Host ""
}
finally {
    Pop-Location
}
