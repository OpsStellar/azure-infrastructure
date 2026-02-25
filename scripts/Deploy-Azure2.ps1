<#
.SYNOPSIS
    PowerShell script to provision Azure infrastructure, deploy services, and destroy resources.

.DESCRIPTION
    This script provides three main operations:
    - Provision: Create Azure infrastructure using Pulumi (AKS, ACR, VNet, etc.)
    - Deploy: Deploy all services to AKS using Helm charts
    - Destroy: Tear down all Azure infrastructure

.PARAMETER Action
    The action to perform: provision, deploy, destroy, or all
    - provision: Create infrastructure with Pulumi
    - deploy: Deploy all services with Helm
    - destroy: Destroy infrastructure with Pulumi
    - all: Provision infrastructure and then deploy services

.PARAMETER Environment
    Target environment: dev, staging, or production (default: dev)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER Services
    Comma-separated list of services to deploy. If not specified, all services are deployed.

.EXAMPLE
    .\Deploy-Azure.ps1 -Action provision -Environment dev
    # Provision dev infrastructure

.EXAMPLE
    .\Deploy-Azure.ps1 -Action deploy -Environment staging
    # Deploy all services to staging

.EXAMPLE
    .\Deploy-Azure.ps1 -Action all -Environment production -Force
    # Provision and deploy to production without prompts

.EXAMPLE
    .\Deploy-Azure.ps1 -Action destroy -Environment dev
    # Destroy dev infrastructure

.EXAMPLE
    .\Deploy-Azure.ps1 -Action deploy -Services "auth-service,frontend"
    # Deploy only auth-service and frontend

.NOTES
    Author: OpsStellar Team
    Requires: Azure CLI, Pulumi, Helm, kubectl
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("provision", "deploy", "destroy", "all")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "production")]
    [string]$Environment = "dev",

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [string]$Services = ""
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$WorkspaceRoot = Split-Path -Parent $ProjectRoot

# Service definitions with their helm chart locations (relative to workspace root)
$AllServices = @(
    @{ Name = "db-service"; Path = "db-service/helm"; Priority = 1 }
    @{ Name = "auth-service"; Path = "auth-service/helm"; Priority = 2 }
    @{ Name = "apm-service"; Path = "apm-service/helm"; Priority = 3 }
    @{ Name = "apm-agent"; Path = "apm-agent/helm"; Priority = 4 }
    @{ Name = "logging-service"; Path = "logging-service/helm"; Priority = 5 }
    @{ Name = "metrics-collector"; Path = "metrics-collector/helm"; Priority = 6 }
    @{ Name = "audit-logs"; Path = "audit-logs/helm"; Priority = 7 }
    @{ Name = "security-service"; Path = "security-service/helm"; Priority = 8 }
    @{ Name = "cost-service"; Path = "cost-service/helm"; Priority = 9 }
    @{ Name = "dora-service"; Path = "dora-service/helm"; Priority = 10 }
    @{ Name = "devops-core"; Path = "devops-core/helm"; Priority = 11 }
    @{ Name = "release-management"; Path = "release-management/helm"; Priority = 12 }
    @{ Name = "settings-service"; Path = "settings-service/helm"; Priority = 13 }
    @{ Name = "chatbot"; Path = "chatbot/helm"; Priority = 14 }
    @{ Name = "microgenie"; Path = "microgenie/helm"; Priority = 15 }
    @{ Name = "testing-services"; Path = "testing-services/helm"; Priority = 16 }
    @{ Name = "frontend"; Path = "frontend/helm"; Priority = 17 }
)

# Color output functions
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Step {
    param([string]$StepNumber, [string]$Message)
    Write-Host ""
    Write-Host "[$StepNumber] $Message" -ForegroundColor Magenta
    Write-Host ("-" * 40) -ForegroundColor DarkGray
}

# Load environment variables from .env file
function Import-EnvFile {
    $envFile = Join-Path $ProjectRoot ".env"
    
    if (-not (Test-Path $envFile)) {
        Write-Error "ERROR: .env file not found at $envFile"
        Write-Host "Create it from the template:" -ForegroundColor Yellow
        Write-Host "  Copy-Item .env.example .env" -ForegroundColor Yellow
        Write-Host "  notepad .env  # Fill in your credentials" -ForegroundColor Yellow
        exit 1
    }

    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
    Write-Success "Environment variables loaded from .env"
}

# Verify required environment variables
function Test-RequiredVariables {
    $required = @(
        "ARM_CLIENT_ID",
        "ARM_CLIENT_SECRET", 
        "ARM_TENANT_ID",
        "ARM_SUBSCRIPTION_ID",
        "AZURE_STORAGE_ACCOUNT",
        "PULUMI_CONFIG_PASSPHRASE"
    )

    $missing = @()
    foreach ($var in $required) {
        $value = [System.Environment]::GetEnvironmentVariable($var, "Process")
        if ([string]::IsNullOrEmpty($value)) {
            $missing += $var
        }
    }

    if ($missing.Count -gt 0) {
        Write-Error "ERROR: Missing required environment variables:"
        $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        exit 1
    }
    Write-Success "All required credentials verified"
}

# Fetch Azure Storage Key if not set
function Get-AzureStorageKey {
    $storageKey = [System.Environment]::GetEnvironmentVariable("AZURE_STORAGE_KEY", "Process")
    
    if ([string]::IsNullOrEmpty($storageKey)) {
        Write-Info "Fetching Azure Storage key..."
        
        if (Get-Command az -ErrorAction SilentlyContinue) {
            try {
                $storageAccount = [System.Environment]::GetEnvironmentVariable("AZURE_STORAGE_ACCOUNT", "Process")
                $storageKey = az storage account keys list `
                    --account-name $storageAccount `
                    --resource-group pulumi-state-rg `
                    --query '[0].value' -o tsv 2>$null
                
                if ($storageKey) {
                    [System.Environment]::SetEnvironmentVariable("AZURE_STORAGE_KEY", $storageKey, "Process")
                    Write-Success "Azure Storage key fetched"
                    return $true
                }
            }
            catch {
                Write-Warning "Failed to fetch AZURE_STORAGE_KEY. Set it manually in .env"
            }
        }
        else {
            Write-Warning "Azure CLI not found. Please set AZURE_STORAGE_KEY in .env"
        }
        return $false
    }
    return $true
}

# Check prerequisites
function Test-Prerequisites {
    Write-Step "1" "Checking Prerequisites"
    
    $tools = @(
        @{ Name = "Azure CLI"; Command = "az" }
        @{ Name = "Pulumi"; Command = "pulumi" }
        @{ Name = "Helm"; Command = "helm" }
        @{ Name = "kubectl"; Command = "kubectl" }
        @{ Name = "Python"; Command = "python" }
    )

    $allFound = $true
    foreach ($tool in $tools) {
        if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
            $version = switch ($tool.Command) {
                "az" { (az version 2>$null | ConvertFrom-Json).'azure-cli' }
                "pulumi" { (pulumi version 2>$null) }
                "helm" { (helm version --short 2>$null) }
                "kubectl" { (kubectl version --client -o json 2>$null | ConvertFrom-Json).clientVersion.gitVersion }
                "python" { (python --version 2>&1).ToString().Split(" ")[1] }
            }
            $toolName = $tool.Name
            Write-Host "  [OK] ${toolName}: $version" -ForegroundColor Green
        }
        else {
            $toolName = $tool.Name
            Write-Host "  [FAIL] ${toolName}: NOT FOUND" -ForegroundColor Red
            $allFound = $false
        }
    }

    if (-not $allFound) {
        Write-Error "Please install missing prerequisites before continuing."
        exit 1
    }
}

# Setup Python virtual environment
function Initialize-PythonVenv {
    Write-Step "2" "Setting up Python Virtual Environment"
    
    Push-Location $ProjectRoot
    try {
        if (-not (Test-Path "venv")) {
            Write-Info "Creating virtual environment..."
            python -m venv venv
            Write-Success "Virtual environment created"
        }
        else {
            Write-Success "Virtual environment already exists"
        }

        # Activate virtual environment
        $activateScript = Join-Path $ProjectRoot "venv\Scripts\Activate.ps1"
        if (Test-Path $activateScript) {
            . $activateScript
            Write-Success "Virtual environment activated"
        }

        # Install requirements
        if (Test-Path "requirements.txt") {
            Write-Info "Installing dependencies..."
            pip install --upgrade pip --quiet
            pip install -r requirements.txt --quiet
            Write-Success "Dependencies installed"
        }
    }
    finally {
        Pop-Location
    }
}

# Login to Pulumi backend
function Connect-PulumiBackend {
    Write-Step "3" "Connecting to Pulumi Backend"
    
    Push-Location $ProjectRoot
    try {
        Write-Info "Logging into Pulumi Azure Blob backend..."
        pulumi login azblob://pulumi-state
        Write-Success "Logged in to Pulumi backend"
    }
    finally {
        Pop-Location
    }
}

# Select or create Pulumi stack
function Select-PulumiStack {
    param([string]$StackName)
    
    Write-Info "Selecting stack: $StackName"
    
    Push-Location $ProjectRoot
    try {
        $existingStack = pulumi stack ls --json 2>$null | ConvertFrom-Json | Where-Object { $_.name -eq $StackName }
        
        if ($existingStack) {
            pulumi stack select $StackName 2>$null
        }
        else {
            Write-Info "Stack '$StackName' not found, creating..."
            pulumi stack init $StackName
        }
        Write-Success "Stack '$StackName' selected"
    }
    finally {
        Pop-Location
    }
}

# Provision infrastructure with Pulumi
function Invoke-Provision {
    Write-Header "Provisioning Infrastructure - $Environment"
    
    # Setup
    Import-EnvFile
    Test-RequiredVariables
    if (-not (Get-AzureStorageKey)) {
        Write-Error "AZURE_STORAGE_KEY is required. Add it to .env or ensure Azure CLI is configured."
        exit 1
    }
    Test-Prerequisites
    Initialize-PythonVenv
    Connect-PulumiBackend
    Select-PulumiStack -StackName $Environment

    Push-Location $ProjectRoot
    try {
        # Preview
        Write-Step "4" "Previewing Changes"
        pulumi preview --diff
        
        if (-not $Force) {
            Write-Host ""
            $confirm = Read-Host "Continue with deployment? (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Warning "Deployment cancelled."
                return
            }
        }

        # Deploy
        Write-Step "5" "Deploying Infrastructure"
        pulumi up --yes
        
        Write-Header "Deployment Complete!"
        
        # Show outputs
        Write-Step "6" "Stack Outputs"
        pulumi stack output

        # Get kubeconfig for AKS
        Write-Step "7" "Configuring kubectl"
        $resourceGroup = pulumi stack output resource_group_name 2>$null
        $aksCluster = pulumi stack output aks_cluster_name 2>$null
        
        if ($resourceGroup -and $aksCluster) {
            az aks get-credentials --resource-group $resourceGroup --name $aksCluster --overwrite-existing
            Write-Success "kubectl configured for AKS cluster: $aksCluster"
        }
    }
    finally {
        Pop-Location
    }
}

# Deploy services with Helm
function Invoke-Deploy {
    param(
        [string[]]$ServiceList = @()
    )
    
    Write-Header "Deploying Services to AKS - $Environment"
    
    # Load env and get cluster credentials
    Import-EnvFile
    
    # Verify kubectl is configured
    Write-Step "1" "Verifying Kubernetes Connection"
    try {
        $context = kubectl config current-context 2>$null
        if ($context) {
            Write-Success "Connected to Kubernetes context: $context"
            kubectl get nodes
        }
        else {
            throw "No Kubernetes context configured"
        }
    }
    catch {
        Write-Error "Cannot connect to Kubernetes cluster."
        Write-Host "Run the following to configure kubectl:" -ForegroundColor Yellow
        Write-Host '  az aks get-credentials --resource-group <rg-name> --name <aks-name>' -ForegroundColor Yellow
        exit 1
    }

    # Create namespace if it doesn't exist
    $namespace = "opsstellar-$Environment"
    Write-Step "2" "Creating Namespace"
    $namespaceExists = kubectl get namespace $namespace 2>$null
    if (-not $namespaceExists) {
        kubectl create namespace $namespace
        Write-Success "Namespace '$namespace' created"
    }
    else {
        Write-Success "Namespace '$namespace' already exists"
    }

    # Get ACR details from Pulumi outputs (if available)
    Push-Location $ProjectRoot
    try {
        $acrLoginServer = pulumi stack output acr_login_server 2>$null
    }
    catch {
        $acrLoginServer = $null
    }
    finally {
        Pop-Location
    }

    # Filter services if specified
    $servicesToDeploy = $AllServices | Sort-Object { $_.Priority }
    
    if ($ServiceList.Count -gt 0) {
        $servicesToDeploy = $servicesToDeploy | Where-Object { 
            $ServiceList -contains $_.Name 
        }
    }

    # Deploy each service
    $serviceCount = $servicesToDeploy.Count
    Write-Step "3" "Deploying Services - $serviceCount total"
    
    $successCount = 0
    $failCount = 0
    
    foreach ($service in $servicesToDeploy) {
        $helmPath = Join-Path $WorkspaceRoot $service.Path
        
        if (-not (Test-Path $helmPath)) {
            $serviceName = $service.Name
            Write-Warning "Helm chart not found for $serviceName at $helmPath"
            $failCount++
            continue
        }

        Write-Host ""
        $serviceName = $service.Name
        Write-Host "  Deploying: $serviceName" -ForegroundColor White
        
        try {
            # Build helm upgrade command with values
            $helmArgs = @(
                "upgrade", "--install"
                $service.Name
                $helmPath
                "--namespace", $namespace
                "--set", "environment=$Environment"
                "--wait"
                "--timeout", "5m"
            )

            # Add ACR registry if available
            if ($acrLoginServer) {
                $helmArgs += "--set", "image.registry=$acrLoginServer"
            }

            # Add values file if exists for environment
            $valuesFile = Join-Path $helmPath "values-$Environment.yaml"
            if (Test-Path $valuesFile) {
                $helmArgs += "-f", $valuesFile
            }

            helm @helmArgs 2>&1 | Out-Null
            $serviceName = $service.Name
            Write-Host "    [OK] $serviceName deployed successfully" -ForegroundColor Green
            $successCount++
        }
        catch {
            $serviceName = $service.Name
            $errorMsg = $_.Exception.Message
            Write-Host "    [FAIL] $serviceName failed: $errorMsg" -ForegroundColor Red
            $failCount++
        }
    }

    # Summary
    Write-Header "Deployment Summary"
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
    
    # Show deployed services
    Write-Step "4" "Deployed Services"
    kubectl get deployments -n $namespace
    
    Write-Host ""
    kubectl get services -n $namespace
}

# Destroy infrastructure with Pulumi
function Invoke-Destroy {
    Write-Header "[WARNING] DESTROYING Infrastructure - $Environment"
    
    Import-EnvFile
    Test-RequiredVariables
    if (-not (Get-AzureStorageKey)) {
        Write-Error "AZURE_STORAGE_KEY is required."
        exit 1
    }
    
    # Activate venv if exists
    $activateScript = Join-Path $ProjectRoot "venv\Scripts\Activate.ps1"
    if (Test-Path $activateScript) {
        . $activateScript
    }

    Connect-PulumiBackend
    Select-PulumiStack -StackName $Environment

    Push-Location $ProjectRoot
    try {
        Write-Host ""
        Write-Host "This will PERMANENTLY DELETE all resources in environment: $Environment" -ForegroundColor Red
        Write-Host "Resources include: AKS cluster, ACR, VNet, Resource Group, and all data!" -ForegroundColor Red
        Write-Host ""
        
        if (-not $Force) {
            $confirm = Read-Host "Type 'destroy' to confirm"
            if ($confirm -ne "destroy") {
                Write-Warning "Cancelled."
                return
            }
        }

        Write-Step "1" "Destroying Infrastructure"
        pulumi destroy --yes
        
        Write-Header "Resources Destroyed"
        Write-Success "All resources in '$Environment' have been deleted."
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    Write-Header "OpsStellar Azure Deployment Script"
    Write-Host "  Action:      $Action" -ForegroundColor White
    Write-Host "  Environment: $Environment" -ForegroundColor White
    Write-Host "  Force:       $Force" -ForegroundColor White
    
    if ($Services) {
        Write-Host "  Services:    $Services" -ForegroundColor White
    }

    switch ($Action) {
        "provision" {
            Invoke-Provision
        }
        "deploy" {
            $serviceArray = @()
            if ($Services) {
                $serviceArray = $Services -split "," | ForEach-Object { $_.Trim() }
            }
            Invoke-Deploy -ServiceList $serviceArray
        }
        "destroy" {
            Invoke-Destroy
        }
        "all" {
            Invoke-Provision
            Write-Host ""
            Write-Host "Waiting 30 seconds for AKS cluster to stabilize..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            $serviceArray = @()
            if ($Services) {
                $serviceArray = $Services -split "," | ForEach-Object { $_.Trim() }
            }
            Invoke-Deploy -ServiceList $serviceArray
        }
    }

    Write-Host ""
    Write-Success "Script completed successfully!"
}

# Run main
Main
