# Azure OIDC + OAuth Setup Guide

This guide explains how to set up Azure infrastructure with OIDC authentication and automated OAuth app registration.

## Prerequisites

- Azure subscription
- GitHub repository
- Azure CLI installed locally

## Option 1: Automated Setup (Recommended)

### Step 1: Initial Azure Login
```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Step 2: Create Initial Service Principal
This is needed only once to bootstrap the setup:
```bash
REPO_OWNER="your-github-username"
REPO_NAME="Library"

# Create service principal
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "gh-bootstrap-${REPO_NAME}" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth)

echo $SP_OUTPUT
```

### Step 3: Add Initial GitHub Secret
Go to GitHub → Settings → Secrets → Actions → New repository secret:
- Name: `AZURE_CREDENTIALS`
- Value: (paste the entire JSON output from Step 2)

Also add:
- `AZURE_SUBSCRIPTION_ID`: Your subscription ID
- `AZURE_TENANT_ID`: Your tenant ID
- `RESOURCE_GROUP`: `virtual-library-rg` (or your preferred name)

### Step 4: Run Setup Workflow
1. Go to GitHub → Actions
2. Select "Setup Azure OIDC" workflow
3. Click "Run workflow"
4. Wait for completion and check the summary for required secrets

### Step 5: Add Generated Secrets
The workflow will output several secrets. Add them to GitHub:
- `AZURE_CLIENT_ID`
- `JWT_SECRET_KEY`
- `MICROSOFT_CLIENT_ID`
- `MICROSOFT_CLIENT_SECRET`

### Step 6: Deploy
Now you can use the regular deployment workflows with OIDC authentication!

## Option 2: Manual Setup

### Create Azure AD App for OAuth
```bash
# Register Microsoft Graph provider
az provider register --namespace Microsoft.Graph --wait

# Deploy with AAD app creation
az deployment group create \
  --resource-group virtual-library-rg \
  --template-file infrastructure/main.bicep \
  --parameters \
    appName=virtual-library \
    environment=prod \
    jwtSecretKey="$(openssl rand -base64 32)" \
    createAadApp=true
```

### Create OIDC Service Principal
```bash
APP_NAME="virtual-library-github-oidc"
REPO="owner/repo"

# Create service principal
SP=$(az ad sp create-for-rbac --name $APP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID)

APP_ID=$(echo $SP | jq -r '.appId')

# Create federated credentials
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$REPO':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Bicep Features

### Conditional Azure AD App Creation
The `main.bicep` now supports:
- `createAadApp=true` - Automatically creates Azure AD app with proper OAuth config
- `createAadApp=false` - Use existing app (provide clientId and clientSecret)

### AAD App Configuration
The `aad-app.bicep` module creates:
- Multi-tenant Azure AD application
- Redirect URIs for web and iOS
- Microsoft Graph API permissions (User.Read, email, profile)
- Client secret (valid for 2 years)

## GitHub Actions with OIDC

All deployment workflows now use OIDC instead of service principal credentials:
- No secrets stored in GitHub (except IDs)
- Federated credentials for main branch, PRs, and environments
- Automatic token exchange during workflow execution

## Advantages

✅ **Security**: No client secrets in GitHub  
✅ **Automation**: Azure AD app created automatically  
✅ **Maintenance**: Federated credentials don't expire  
✅ **Compliance**: Follows Azure best practices
