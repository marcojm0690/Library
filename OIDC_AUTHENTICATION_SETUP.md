# Azure OIDC Authentication Setup

## What Changed

Your GitHub Actions workflows now use **OpenID Connect (OIDC)** instead of passwords/secrets. This provides:

✅ **Auto-refreshing tokens** - No manual credential updates needed
✅ **Enhanced security** - No secrets stored in GitHub
✅ **Federated identity** - GitHub authenticates directly with Azure AD

## Configuration Summary

### Azure Service Principal
- **Client ID**: `94236f3f-6dca-4635-a2ed-b312ac1334c8`
- **Tenant ID**: `eb314fdf-b6a0-4945-88ea-026fbf7a3e4e`
- **Subscription ID**: `68099df3-299d-4530-aaa9-9693305c119a`
- **Name**: `virtual-library-github-actions`

### Permissions Granted
- **Contributor** on subscription (for resource management)
- **AcrPush** on ACR `virtuallibraryacr` (for pushing Docker images)

### Federated Identity
- **Repository**: `marcojm0690/Library`
- **Branch**: `main`
- **Issuer**: GitHub Actions (`https://token.actions.githubusercontent.com`)

## Updated Workflows

### 1. build-and-push.yml
- Uses OIDC authentication via `azure/login@v2`
- Automatically logs into ACR using Azure identity
- **No secrets required** ✨

### 2. deploy-webapp.yml
- Uses OIDC authentication
- Deploys to Azure Web App
- **No secrets required** ✨

## How It Works

1. GitHub Actions requests a token from GitHub's OIDC provider
2. GitHub issues a signed JWT token
3. Azure AD validates the token against the federated credential
4. Azure AD issues an access token for your service principal
5. Workflow can now authenticate to Azure services

## What You Can Remove

You can now **delete these GitHub secrets** (they're no longer used):
- `AZURE_CREDENTIALS`
- `ACR_USERNAME`
- `ACR_PASSWORD`
- `ACR_LOGIN_SERVER` (now hardcoded in workflow)

## Testing

Push your changes to the `main` branch:

```bash
git add .github/workflows/
git commit -m "Switch to OIDC authentication for GitHub Actions"
git push origin main
```

The workflows will automatically authenticate using OIDC. No manual intervention needed! 🎉

## Troubleshooting

If authentication fails:
1. Verify the federated credential matches your repository
2. Check that `permissions.id-token: write` is set in the workflow
3. Ensure the service principal has the necessary role assignments

## For Other Branches

To add OIDC support for other branches (e.g., `dev`), create additional federated credentials:

```bash
az ad app federated-credential create \
  --id 94236f3f-6dca-4635-a2ed-b312ac1334c8 \
  --parameters '{
    "name": "github-actions-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:marcojm0690/Library:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```
