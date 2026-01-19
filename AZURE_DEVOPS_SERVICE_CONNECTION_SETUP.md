# Azure DevOps Service Connection Setup Guide

## Issue Fixed
The pipeline was failing with authentication error because it was referencing a non-existent service connection variable. This has been fixed in [azure-pipelines-complete.yml](azure-pipelines-complete.yml).

## Required Service Connections

You need to create TWO service connections in Azure DevOps:

### 1. Azure Resource Manager Service Connection
For deploying infrastructure and managing Azure resources.

### 2. Azure Container Registry Service Connection
For pushing Docker images to ACR.

---

## Step-by-Step Setup

### Step 1: Create Azure Service Connection

1. **Go to Azure DevOps**
   - Navigate to: `https://dev.azure.com/[your-org]/[your-project]`

2. **Open Project Settings**
   - Click the gear icon (⚙️) at the bottom left
   - Or go to: Project Settings → Service connections

3. **Create New Service Connection**
   - Click "+ New service connection"
   - Select **"Azure Resource Manager"**
   - Click "Next"

4. **Choose Authentication Method**
   - Select **"Service principal (automatic)"** (recommended)
   - Or **"Service principal (manual)"** if you need specific permissions

5. **Configure Connection (Automatic)**
   - **Subscription**: Select your Azure subscription
   - **Resource group**: Select `biblioteca` (or leave empty for all)
   - **Service connection name**: `azure-service-connection` 
     *(Must match the name in pipeline YAML)*
   - **Description**: "Azure subscription for Virtual Library deployment"
   - ✅ Check "Grant access permission to all pipelines"
   - Click "Save"

6. **Configure Connection (Manual) - If Using Manual**
   ```bash
   # Create a service principal
   az ad sp create-for-rbac --name "virtual-library-devops-sp" \
     --role Contributor \
     --scopes /subscriptions/{subscription-id}/resourceGroups/biblioteca
   
   # Output will show:
   # {
   #   "appId": "xxx",        # Use as Client ID
   #   "displayName": "...",
   #   "password": "xxx",     # Use as Client Secret
   #   "tenant": "xxx"        # Use as Tenant ID
   # }
   ```
   
   Fill in Azure DevOps:
   - **Service Principal Id**: `appId` from above
   - **Service Principal Key**: `password` from above  
   - **Tenant ID**: `tenant` from above
   - **Subscription ID**: Your Azure subscription ID
   - **Subscription Name**: Your subscription name

### Step 2: Create ACR Service Connection

1. **Create Another Service Connection**
   - Click "+ New service connection"
   - Select **"Docker Registry"**
   - Click "Next"

2. **Configure Docker Registry**
   - **Registry type**: Azure Container Registry
   - **Subscription**: Select your Azure subscription
   - **Azure container registry**: Select `virtuallibraryacr`
   - **Service connection name**: `virtuallibraryacr`
     *(Must match dockerRegistryServiceConnection in pipeline)*
   - ✅ Check "Grant access permission to all pipelines"
   - Click "Save"

---

## Alternative: Quick Setup via Azure CLI

### Option A: Automatic Service Connection (Requires Azure DevOps Extension)

```bash
# Install Azure DevOps extension
az extension add --name azure-devops

# Login and set defaults
az login
az devops configure --defaults organization=https://dev.azure.com/[your-org] project=[your-project]

# Create service endpoint
az devops service-endpoint azurerm create \
  --azure-rm-service-principal-id $(az account show --query id -o tsv) \
  --azure-rm-subscription-id $(az account show --query id -o tsv) \
  --azure-rm-subscription-name "$(az account show --query name -o tsv)" \
  --azure-rm-tenant-id $(az account show --query tenantId -o tsv) \
  --name azure-service-connection
```

### Option B: Use Existing Service Connection

If you already have a service connection, update the pipeline:

```yaml
# In azure-pipelines-complete.yml, line 12
azureServiceConnection: 'YOUR_EXISTING_CONNECTION_NAME'  # Replace with your connection name
```

---

## Verify Service Connections

### In Azure DevOps UI:
1. Go to: **Project Settings** → **Service connections**
2. You should see:
   - ✅ `azure-service-connection` (Type: Azure Resource Manager)
   - ✅ `virtuallibraryacr` (Type: Docker Registry)
3. Click each connection and verify:
   - Status shows "Ready"
   - "Grant access permission to all pipelines" is checked

### Test Service Connection:
1. Click on `azure-service-connection`
2. Click "Verify" button
3. Should show green checkmark ✅

---

## Update Pipeline Variable (If Using Different Name)

If you named your service connection differently, update the pipeline:

**File**: `azure-pipelines-complete.yml`

```yaml
variables:
  # Update this line with your actual service connection name
  azureServiceConnection: 'YOUR_CONNECTION_NAME'  # ← Change this
  dockerRegistryServiceConnection: 'virtuallibraryacr'
  # ... rest of variables
```

---

## Troubleshooting

### Error: "Service connection not found"
**Cause**: The service connection name in YAML doesn't match Azure DevOps

**Fix**:
1. Check exact name in: Project Settings → Service connections
2. Update `azureServiceConnection` variable in pipeline YAML
3. Ensure no extra spaces or typos

### Error: "Insufficient permissions"
**Cause**: Service principal doesn't have required permissions

**Fix**:
```bash
# Grant Contributor role to the service principal
sp_id="<appId from service principal>"
subscription_id=$(az account show --query id -o tsv)

az role assignment create \
  --assignee $sp_id \
  --role Contributor \
  --scope /subscriptions/$subscription_id/resourceGroups/biblioteca
```

### Error: "Could not find ACR"
**Cause**: ACR service connection not properly configured

**Fix**:
1. Verify ACR exists: `az acr show --name virtuallibraryacr`
2. Recreate Docker Registry service connection
3. Ensure it's granted access to all pipelines

### Error: "Authentication timeout"
**Cause**: Service connection credentials expired

**Fix**:
1. Edit the service connection
2. Click "Verify" 
3. Re-authenticate if prompted
4. If using manual service principal, create new secret:
   ```bash
   az ad sp credential reset --name virtual-library-devops-sp
   ```

---

## Required Permissions Summary

The service principal needs these permissions:

| Resource | Permission | Scope |
|----------|------------|-------|
| Resource Group | Contributor | `/subscriptions/{sub}/resourceGroups/biblioteca` |
| Container Registry | AcrPush | `/subscriptions/{sub}/resourceGroups/biblioteca/providers/Microsoft.ContainerRegistry/registries/virtuallibraryacr` |
| Web App | Contributor | Auto-granted via Resource Group |

---

## After Setup

Once service connections are created:

1. **Commit and push the updated pipeline**:
   ```bash
   git add azure-pipelines-complete.yml
   git commit -m "fix: update Azure service connection references"
   git push origin main
   ```

2. **Run the pipeline** in Azure DevOps

3. **Monitor the logs** - authentication errors should be resolved

4. **Pipeline stages should complete**:
   - ✅ Deploy Infrastructure
   - ✅ Build and push Docker image
   - ✅ Deploy to Web App

---

## Quick Verification Script

```bash
#!/bin/bash
# Save as verify-service-connections.sh

echo "=== Verifying Azure Resources ==="

# Check if logged in
if ! az account show &>/dev/null; then
    echo "❌ Not logged into Azure. Run: az login"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "✅ Subscription: $SUBSCRIPTION_ID"
echo "✅ Tenant: $TENANT_ID"

# Check resource group
if az group show --name biblioteca &>/dev/null; then
    echo "✅ Resource group 'biblioteca' exists"
else
    echo "❌ Resource group 'biblioteca' not found"
fi

# Check ACR
if az acr show --name virtuallibraryacr &>/dev/null; then
    echo "✅ ACR 'virtuallibraryacr' exists"
else
    echo "❌ ACR 'virtuallibraryacr' not found"
fi

echo ""
echo "Next steps:"
echo "1. Create service connection in Azure DevOps with these values:"
echo "   - Subscription ID: $SUBSCRIPTION_ID"
echo "   - Tenant ID: $TENANT_ID"
echo "   - Name: azure-service-connection"
echo ""
echo "2. Create Docker Registry connection for: virtuallibraryacr"
```

---

## Success Checklist

- [ ] Azure service connection created and verified
- [ ] ACR service connection created and verified
- [ ] Pipeline YAML updated with correct connection names
- [ ] Service connections granted access to all pipelines
- [ ] Pipeline runs without authentication errors
- [ ] All three stages complete successfully

Once all checkboxes are complete, your pipeline should deploy successfully! 🚀
