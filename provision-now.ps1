# Direct Pulumi Provisioning Script
$ErrorActionPreference = "Continue"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Azure Infrastructure Provisioning" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Set PATH
$env:Path = "$env:USERPROFILE\.pulumi\p ulumi\bin;$env:USERPROFILE\.helm;$env:Path"

# Change to project directory
Set-Location d:\OS\git\azure-infrastructure

# Load environment variables
Write-Host "[1] Loading .env file..." -ForegroundColor Yellow
Get-Content .env | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]+)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}
Write-Host "    OK - Environment loaded" -ForegroundColor Green

# Setup Python venv
Write-Host "[2] Setting up Python environment..." -ForegroundColor Yellow
if (-not (Test-Path venv)) {
    python -m venv venv
}
.\venv\Scripts\Activate.ps1
pip install -q -r requirements.txt
Write-Host "    OK - Python environment ready" -ForegroundColor Green

# Login to Pulumi
Write-Host "[3] Logging into Pulumi..." -ForegroundColor Yellow
pulumi login azblob://pulumi-state
Write-Host "    OK - Logged into Pulumi" -ForegroundColor Green

# Select stack
Write-Host "[4] Selecting 'dev' stack..." -ForegroundColor Yellow
pulumi stack select dev 2>$null
if ($LASTEXITCODE -ne 0) {
    pulumi stack init dev
}
Write-Host "    OK - Stack 'dev' selected" -ForegroundColor Green

# Preview
Write-Host "[5] Previewing infrastructure changes..." -ForegroundColor Yellow
pulumi preview --diff

# Deploy
Write-Host "" 
Write-Host "=========================================" -ForegroundColor Yellow
$confirm = Read-Host "Deploy infrastructure? (y/N)"
if ($confirm -eq "y" -or $confirm -eq "Y") {
    Write-Host "[6] Deploying infrastructure..." -ForegroundColor Yellow
    pulumi up --yes
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Deployment Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    pulumi stack output
} else {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
}
