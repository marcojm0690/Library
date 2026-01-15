# Virtual Library Infrastructure

This directory contains the Azure Resource Manager (Bicep) infrastructure templates for deploying the Virtual Library API application.

## Files

- `main.bicep` - Main Bicep template that defines all Azure resources
- `parameters.json` - Parameter values for the deployment
- `deploy.sh` - Shell script to deploy the infrastructure

## Prerequisites

- Azure CLI installed and configured
- Active Azure subscription
- Appropriate permissions to create resources in the subscription

## Resources Created

The Bicep template provisions the following Azure resources:

### Compute & Networking
- **Azure Container Registry (ACR)** - For storing Docker images
- **App Service Plan** - Linux B1 tier
- **App Service (Web App)** - Runs the API in Docker containers
- **Virtual Network** - For private networking

### Data
- **Azure Cosmos DB** - MongoDB API for document storage
- **Database** - LibraryDb
- **Collection** - Books

### Security & Access
- **Managed Identity** - System-assigned identity for the web app
- **Role Assignments** - AcrPull (web app can pull images from ACR)
- **Cosmos DB Access** - Web app can access the database

## Deployment

### Option 1: Using the deploy script (Recommended)

```bash
cd /path/to/Library
./infrastructure/deploy.sh
```

The script will:
1. Create the resource group if it doesn't exist
2. Validate the Bicep template
3. Deploy all resources
4. Display the deployment outputs

### Option 2: Using Azure CLI directly

```bash
az deployment group create \
  -g biblioteca \
  -f infrastructure/main.bicep \
  -p infrastructure/parameters.json
```

### Option 3: Using Azure Pipelines

Update your Azure Pipelines YAML file to include the infrastructure deployment stage:

```yaml
- stage: DeployInfrastructure
  displayName: Deploy Infrastructure
  jobs:
    - job: DeployBicep
      steps:
        - task: AzureResourceGroupDeployment@2
          inputs:
            csmFile: '$(Build.SourcesDirectory)/infrastructure/main.bicep'
            csmParametersFile: '$(Build.SourcesDirectory)/infrastructure/parameters.json'
```

## Deployment Outputs

After deployment, you'll receive the following outputs:

```json
{
  "acrLoginServer": "virtuallibraryacr.azurecr.io",
  "acrName": "virtuallibraryacr",
  "webAppUrl": "https://virtual-library-api-web.azurewebsites.net",
  "webAppName": "virtual-library-api-web",
  "cosmosDbEndpoint": "https://virtual-library-server.documents.azure.com:443/",
  "webAppPrincipalId": "b577378e-ce25-4ecf-ae35-22f3918ecf3d"
}
```

## Next Steps

1. **Build Docker Image**
   ```bash
   docker build -t virtuallibraryacr.azurecr.io/virtual-library-api:latest .
   ```

2. **Push to ACR**
   ```bash
   az acr login -n virtuallibraryacr
   docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest
   ```

3. **Access the Application**
   - API: https://virtual-library-api-web.azurewebsites.net
   - Swagger UI: https://virtual-library-api-web.azurewebsites.net/swagger/index.html

## Configuration

Edit `parameters.json` to customize the deployment:

```json
{
  "location": "canadacentral",
  "environment": "prod",
  "appName": "virtual-library"
}
```

## Troubleshooting

### Deployment Failed
```bash
# Check deployment operations
az deployment group show -g biblioteca -n main --query "properties.outputs"

# View detailed error
az deployment operation group list -g biblioteca --deployment-name main
```

### Resources Not Created
```bash
# List all resources in the resource group
az resource list -g biblioteca --query "[].{name:name, type:type}"
```

### Web App Can't Pull Image
Ensure:
1. Docker image is pushed to ACR
2. Web app has AcrPull role on the ACR
3. Managed identity is enabled on the web app

## Updating Infrastructure

To update the infrastructure, modify the Bicep template and redeploy:

```bash
./infrastructure/deploy.sh
```

The deployment is incremental, so only changed resources will be updated.

## Cost Optimization

To reduce costs:
- Change App Service Plan SKU from B1 to F1 (free tier) in `main.bicep`
- Set Cosmos DB to use serverless or reserved capacity
- Enable auto-shutdown for non-production environments

## Security Best Practices

- [ ] Enable private endpoints for Cosmos DB
- [ ] Configure network security groups
- [ ] Enable Azure Monitor logging
- [ ] Use Key Vault for secrets
- [ ] Implement RBAC with least-privilege principle
- [ ] Enable Azure Defender for Azure resources

## Documentation

- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)
- [Azure App Service](https://learn.microsoft.com/azure/app-service/)
- [Azure Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/)
