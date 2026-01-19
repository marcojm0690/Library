# GitHub Actions Setup Guide

This project uses GitHub Actions for continuous integration and deployment to Azure. The workflow automatically deploys infrastructure, builds Docker images, and deploys to Azure Web App.

## Prerequisites

- Azure subscription
- GitHub repository with admin access
- Azure CLI installed locally (for initial setup)

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository:

### 1. AZURE_CREDENTIALS

This contains the service principal credentials for Azure authentication.

**Create the service principal:**

```bash
az ad sp create-for-rbac \
  --name "virtual-library-github-actions" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/biblioteca \
  --sdk-auth
```

Replace `{subscription-id}` with your Azure subscription ID. You can get it with:

```bash
az account show --query id -o tsv
```

**Expected output format:**
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**Copy the entire JSON output** and add it as a GitHub secret.

### 2. AZURE_SUBSCRIPTION_ID

Your Azure subscription ID (same as in the AZURE_CREDENTIALS JSON).

```bash
az account show --query id -o tsv
```

## Adding Secrets to GitHub

### Via GitHub Web UI:

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:
   - **Name**: `AZURE_CREDENTIALS`
   - **Value**: Paste the entire JSON output from the service principal creation
   - Click **Add secret**
5. Repeat for `AZURE_SUBSCRIPTION_ID`

### Via GitHub CLI:

```bash
# Set AZURE_CREDENTIALS
gh secret set AZURE_CREDENTIALS < credentials.json

# Set AZURE_SUBSCRIPTION_ID
gh secret set AZURE_SUBSCRIPTION_ID --body "your-subscription-id"
```

## Workflow Configuration

The workflow is located at [.github/workflows/deploy.yml](.github/workflows/deploy.yml) and consists of three jobs:

### 1. Deploy Infrastructure
- Deploys Azure resources using Bicep templates
- Creates/updates: App Service, Container Registry, Cosmos DB, etc.
- Outputs the Web App name for deployment

### 2. Build and Push Docker Image
- Builds the Docker image from the Dockerfile
- Pushes to Azure Container Registry
- Tags with both build number and 'latest'

### 3. Deploy to Web App
- Deploys the container to Azure App Service
- Configures the Web App with the new image
- Provides deployment URL

## Triggering the Workflow

The workflow triggers automatically on:
- **Push to main branch** - Automatic deployment
- **Manual trigger** - Via GitHub Actions UI ("Run workflow" button)

## Monitoring Deployments

1. Go to **Actions** tab in your GitHub repository
2. Click on the latest workflow run
3. View logs for each job
4. Check deployment URL in the "Deploy to Web App" job output

## Environment Variables

Update these in [.github/workflows/deploy.yml](.github/workflows/deploy.yml) if needed:

```yaml
env:
  AZURE_RESOURCE_GROUP: biblioteca        # Your resource group name
  AZURE_LOCATION: canadacentral          # Azure region
  ACR_NAME: virtuallibraryacr            # Container registry name
  IMAGE_NAME: virtual-library-api         # Docker image name
  REGISTRY: virtuallibraryacr.azurecr.io # Full registry URL
```

## Troubleshooting

### Authentication Errors

If you see authentication errors:
1. Verify secrets are set correctly in GitHub
2. Check service principal has correct permissions:
   ```bash
   az role assignment list --assignee {clientId} --output table
   ```
3. Ensure the service principal has Contributor access to the resource group

### Image Push Errors

If Docker push fails:
1. Verify ACR exists: `az acr list -o table`
2. Check ACR admin credentials are enabled (or use service principal)
3. Ensure the workflow has logged into ACR successfully

### Deployment Failures

If Web App deployment fails:
1. Check the Web App exists in the resource group
2. Verify the container image was pushed successfully
3. Check Web App logs: `az webapp log tail --name {webapp-name} --resource-group biblioteca`

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Login Action](https://github.com/Azure/login)
- [Azure Web Apps Deploy Action](https://github.com/Azure/webapps-deploy)
- [Azure ARM Deploy Action](https://github.com/Azure/arm-deploy)

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Use environment protection rules** for production deployments
3. **Rotate service principal credentials** regularly
4. **Use least-privilege access** - scope service principal to specific resource group
5. **Enable branch protection** on main branch to require PR reviews

## Migration from Azure DevOps

This setup replaces the previous Azure DevOps pipelines with GitHub Actions, providing:
- ✅ Native GitHub integration
- ✅ Better visibility in PRs and commits
- ✅ Simplified secret management
- ✅ No external service connections needed
- ✅ Free CI/CD minutes for public repos
