# Azure Pipeline Deployment Troubleshooting Guide

## Issue: Deploy Web App Task Failing

### Fix Applied ✅
Updated [azure-pipelines-complete.yml](azure-pipelines-complete.yml) deployment stage:
- **Changed**: `AzureWebApp@1` → `AzureWebAppContainer@1` (correct task for containers)
- **Added**: Dynamic web app name discovery from resource group
- **Removed**: Unnecessary checkout step in deploy stage

## Common Deployment Failure Causes

### 1. **Container Won't Start (Most Common)**
**Symptoms**: Deploy succeeds but app shows "Application Error" or container restarts repeatedly

**Diagnose**:
```bash
# Check container logs
az webapp log tail --name virtual-library-api-web --resource-group biblioteca

# Check deployment logs
az webapp log deployment show --name virtual-library-api-web --resource-group biblioteca
```

**Possible Causes**:
- ❌ Missing MongoDB connection string
- ❌ Invalid Cosmos DB credentials
- ❌ Port mismatch (app listening on wrong port)
- ❌ Missing required environment variables

**Fix**:
```bash
# Verify app settings are correct
az webapp config appsettings list \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --query "[?contains(name, 'Azure')].{name:name, value:value}" -o table

# Ensure MongoDB connection string is set
az webapp config appsettings set \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --settings Azure__MongoDB__SeedMockData="false"
```

### 2. **RBAC Permissions Missing**
**Symptoms**: "403 Forbidden" errors in logs, can't pull from ACR

**Diagnose**:
```bash
# Check if Web App has ACR pull permission
webAppPrincipalId=$(az webapp identity show \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --query principalId -o tsv)

az role assignment list \
  --assignee $webAppPrincipalId \
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/biblioteca
```

**Fix**:
```bash
# Assign ACR Pull role to Web App managed identity
acrId=$(az acr show --name virtuallibraryacr --query id -o tsv)
az role assignment create \
  --assignee $webAppPrincipalId \
  --role AcrPull \
  --scope $acrId
```

### 3. **Image Not Found in ACR**
**Symptoms**: "Image not found" or "manifest unknown" errors

**Diagnose**:
```bash
# List images in ACR
az acr repository list --name virtuallibraryacr -o table

# Check specific image tags
az acr repository show-tags \
  --name virtuallibraryacr \
  --repository virtual-library-api \
  --orderby time_desc \
  --output table
```

**Fix**: Ensure Build stage completed successfully and pushed the image.

### 4. **Web App Not Using Managed Identity for ACR**
**Symptoms**: ACR login failures despite correct RBAC

**Fix**:
```bash
# Enable managed identity for ACR access
az webapp config set \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --generic-configurations '{"acrUseManagedIdentityCreds": true}'

# Restart the app
az webapp restart \
  --name virtual-library-api-web \
  --resource-group biblioteca
```

### 5. **Cosmos DB Connection Issues**
**Symptoms**: App starts but can't connect to database

**Diagnose**:
```bash
# Test connection string
connectionString=$(az cosmosdb keys list \
  --name virtual-library-server \
  --resource-group biblioteca \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" -o tsv)

echo "Connection string (check if valid): ${connectionString:0:50}..."
```

**Fix**:
```bash
# Update connection string in app settings
az webapp config appsettings set \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --settings "Azure__MongoDB__ConnectionString=$connectionString"
```

## Pipeline Variables to Verify

Ensure these variables are set in Azure DevOps:

| Variable | Value | Where to Set |
|----------|-------|--------------|
| `azureSubscriptionId` | Your Azure subscription service connection | Pipeline > Variables |
| `dockerRegistryServiceConnection` | `virtuallibraryacr` | Pipeline YAML |
| `resourceGroupName` | `biblioteca` | Pipeline YAML |
| `location` | `canadacentral` | Pipeline YAML |

## Step-by-Step Deployment Verification

### After Pipeline Runs:

```bash
# 1. Verify infrastructure exists
az group show --name biblioteca

# 2. Check Cosmos DB status
az cosmosdb show \
  --name virtual-library-server \
  --resource-group biblioteca \
  --query "{name:name, status:provisioningState, endpoint:documentEndpoint}"

# 3. Check ACR
az acr show \
  --name virtuallibraryacr \
  --query "{name:name, loginServer:loginServer, provisioningState:provisioningState}"

# 4. Check Web App
az webapp show \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --query "{name:name, state:state, defaultHostName:defaultHostName, outboundIpAddresses:outboundIpAddresses}"

# 5. Check container settings
az webapp config container show \
  --name virtual-library-api-web \
  --resource-group biblioteca

# 6. Test the API
webAppUrl=$(az webapp show \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --query defaultHostName -o tsv)

curl -I "https://$webAppUrl/swagger"
```

## Quick Health Check Command

```bash
#!/bin/bash
RG="biblioteca"
WEBAPP="virtual-library-api-web"

echo "=== Web App Status ==="
az webapp show --name $WEBAPP --resource-group $RG \
  --query "{state:state, httpsOnly:httpsOnly}" -o table

echo -e "\n=== Recent Logs ==="
az webapp log tail --name $WEBAPP --resource-group $RG --only-show-errors &
TAIL_PID=$!
sleep 10
kill $TAIL_PID 2>/dev/null

echo -e "\n=== App Settings (filtered) ==="
az webapp config appsettings list --name $WEBAPP --resource-group $RG \
  --query "[?contains(name, 'Azure') || contains(name, 'ASPNETCORE')].{name:name, value:value}" -o table

echo -e "\n=== Test API Endpoint ==="
URL=$(az webapp show --name $WEBAPP --resource-group $RG --query defaultHostName -o tsv)
curl -sI "https://$URL/swagger" | head -1
```

Save this as `check-webapp-health.sh` and run after deployments.

## Monitoring & Debugging

### Enable Application Insights (Recommended)
```bash
# Create Application Insights
az monitor app-insights component create \
  --app virtual-library-insights \
  --location canadacentral \
  --resource-group biblioteca \
  --application-type web

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app virtual-library-insights \
  --resource-group biblioteca \
  --query instrumentationKey -o tsv)

# Configure Web App to use it
az webapp config appsettings set \
  --name virtual-library-api-web \
  --resource-group biblioteca \
  --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=$INSTRUMENTATION_KEY"
```

### Stream Logs in Real-Time
```bash
az webapp log tail \
  --name virtual-library-api-web \
  --resource-group biblioteca
```

## Expected Successful Output

When deployment succeeds:
```
✅ Deploy stage completes
✅ curl https://virtual-library-api-web.azurewebsites.net returns 200
✅ Swagger UI accessible at /swagger
✅ Logs show "Application started" message
```

## Next Steps After Fixing

1. Monitor the pipeline run after pushing the fix
2. If Build stage succeeds but Deploy fails, check logs immediately
3. Verify Web App settings match infrastructure outputs
4. Test API endpoints once deployment succeeds

---

**Pipeline Fixed**: ✅ Yes (commit 6343c81)  
**Awaiting**: New pipeline run completion
