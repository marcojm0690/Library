#!/usr/bin/env bash
set -euo pipefail

# Purpose: Provision all Azure resources needed for Virtual Library API deployment on Linux Container
# Requirements: Azure CLI logged in, subscription selected
# Usage:
#   ./scripts/provision-azure-resources.sh

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Virtual Library Azure Resources Provisioning${NC}"
echo "=============================================="

# Configuration
RG=${RG:-"VirtualLibraryRG"}
LOCATION=${LOCATION:-"canadacentral"}
ACR_NAME=${ACR_NAME:-"virtuallibraryacr"}
STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME:-"vllibrarystorage$(date +%s | tail -c 5)"}
COSMOS_ACCOUNT_NAME=${COSMOS_ACCOUNT_NAME:-"virtuallibrary-server"}
PLAN_NAME=${PLAN_NAME:-"vl-asp-linux"}
WEBAPP_NAME=${WEBAPP_NAME:-"virtual-library-api-web"}
VISION_NAME=${VISION_NAME:-"vl-vision-$(date +%s | tail -c 5)"}

echo -e "${YELLOW}Configuration:${NC}"
echo "  Resource Group: $RG"
echo "  Location: $LOCATION"
echo "  ACR Name: $ACR_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Cosmos DB Account: $COSMOS_ACCOUNT_NAME"
echo "  App Service Plan: $PLAN_NAME"
echo "  Web App: $WEBAPP_NAME"
echo "  Vision Service: $VISION_NAME"
echo ""

# Step 1: Create Resource Group
echo -e "${YELLOW}1. Creating Resource Group...${NC}"
az group create -n "$RG" -l "$LOCATION" --only-show-errors
echo -e "${GREEN}✓ Resource Group created${NC}"

# Step 2: Create Azure Container Registry (Linux compatible)
echo -e "${YELLOW}2. Creating Azure Container Registry...${NC}"
if az acr show -n "$ACR_NAME" -g "$RG" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ ACR already exists${NC}"
else
  az acr create \
    -g "$RG" \
    -n "$ACR_NAME" \
    --sku Basic \
    --admin-enabled false \
    --only-show-errors
  echo -e "${GREEN}✓ ACR created${NC}"
fi

# Step 3: Create Storage Account
echo -e "${YELLOW}3. Creating Storage Account...${NC}"
if az storage account show -n "$STORAGE_ACCOUNT_NAME" -g "$RG" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Storage Account already exists${NC}"
else
  az storage account create \
    -g "$RG" \
    -n "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --https-only true \
    --only-show-errors
  echo -e "${GREEN}✓ Storage Account created${NC}"
fi

# Step 4: Create blob container
echo -e "${YELLOW}4. Creating Blob Container...${NC}"
az storage container create \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --name "user-libraries" \
  --public-access off \
  --only-show-errors || true
echo -e "${GREEN}✓ Blob Container ready${NC}"

# Step 5: Create Cosmos DB Account (SQL API)
echo -e "${YELLOW}5. Creating Azure Cosmos DB Account...${NC}"
if az cosmosdb show -n "$COSMOS_ACCOUNT_NAME" -g "$RG" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Cosmos DB Account already exists${NC}"
else
  az cosmosdb create \
    -g "$RG" \
    -n "$COSMOS_ACCOUNT_NAME" \
    --kind GlobalDocumentDB \
    --locations regionName="$LOCATION" failoverPriority=0 \
    --default-consistency-level "Session" \
    --only-show-errors
  echo -e "${GREEN}✓ Cosmos DB Account created${NC}"
fi

# Get Cosmos DB endpoint
COSMOS_ENDPOINT=$(az cosmosdb show -n "$COSMOS_ACCOUNT_NAME" -g "$RG" --query "documentEndpoint" -o tsv)
echo -e "${GREEN}Cosmos DB Endpoint: $COSMOS_ENDPOINT${NC}"

# Step 6: Create Azure Cognitive Services (Vision)
echo -e "${YELLOW}5. Creating Azure Cognitive Services (Vision API)...${NC}"
if az cognitiveservices account show -n "$VISION_NAME" -g "$RG" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Vision Service already exists${NC}"
else
  az cognitiveservices account create \
    -g "$RG" \
    -n "$VISION_NAME" \
    --kind ComputerVision \
    --sku S1 \
    --location "$LOCATION" \
    --yes \
    --only-show-errors
  echo -e "${GREEN}✓ Vision Service created${NC}"
fi

# Get Vision endpoint
VISION_ENDPOINT=$(az cognitiveservices account show -n "$VISION_NAME" -g "$RG" --query properties.endpoint -o tsv)
echo -e "${GREEN}Vision Endpoint: $VISION_ENDPOINT${NC}"

# Step 6: Create App Service Plan (Linux)
echo -e "${YELLOW}6. Creating App Service Plan (Linux)...${NC}"
if az appservice plan show -g "$RG" -n "$PLAN_NAME" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ App Service Plan already exists${NC}"
else
  az appservice plan create \
    -g "$RG" \
    -n "$PLAN_NAME" \
    --is-linux \
    --sku B1 \
    --only-show-errors
  echo -e "${GREEN}✓ App Service Plan created (Linux)${NC}"
fi

# Step 7: Create Web App (Linux Container)
echo -e "${YELLOW}7. Creating Web App (Linux Container)...${NC}"
if az webapp show -g "$RG" -n "$WEBAPP_NAME" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Web App already exists${NC}"
else
  az webapp create \
    -g "$RG" \
    -p "$PLAN_NAME" \
    -n "$WEBAPP_NAME" \
    -i mcr.microsoft.com/azuredocs/aci-helloworld:latest \
    --only-show-errors
  echo -e "${GREEN}✓ Web App created (Linux)${NC}"
fi

# Step 8: Enable system-assigned managed identity
echo -e "${YELLOW}8. Enabling Managed Identity...${NC}"
PRINCIPAL_ID=$(az webapp identity assign \
  -g "$RG" \
  -n "$WEBAPP_NAME" \
  --query principalId -o tsv)
echo -e "${GREEN}✓ Managed Identity enabled: $PRINCIPAL_ID${NC}"

# Step 9: Grant RBAC Roles
echo -e "${YELLOW}9. Granting RBAC Roles...${NC}"

# AcrPull role for ACR
ACR_ID=$(az acr show -n "$ACR_NAME" --query id -o tsv)
echo "  Granting AcrPull to ACR..."
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role AcrPull \
  --scope "$ACR_ID" \
  --only-show-errors || true

# Storage Blob Data Contributor role
STORAGE_ID=$(az storage account show -n "$STORAGE_ACCOUNT_NAME" -g "$RG" --query id -o tsv)
echo "  Granting Storage Blob Data Contributor..."
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID" \
  --only-show-errors || true

# Cognitive Services User role
VISION_ID=$(az cognitiveservices account show -n "$VISION_NAME" -g "$RG" --query id -o tsv)
echo "  Granting Cognitive Services User..."
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Cognitive Services User" \
  --scope "$VISION_ID" \
  --only-show-errors || true

# Cosmos DB Built-in Data Contributor role
COSMOS_ID=$(az cosmosdb show -n "$COSMOS_ACCOUNT_NAME" -g "$RG" --query id -o tsv)
echo "  Granting Cosmos DB Built-in Data Contributor..."
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Cosmos DB Built-in Data Contributor" \
  --scope "$COSMOS_ID" \
  --only-show-errors || true

echo -e "${GREEN}✓ RBAC roles assigned${NC}"

# Step 10: Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Provisioning Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Set GitHub Secrets (if using GitHub Actions):"
echo "   - ACR_LOGIN_SERVER = $ACR_NAME.azurecr.io"
echo "   - STORAGE_ACCOUNT_NAME = $STORAGE_ACCOUNT_NAME"
echo "   - AZURE_VISION_ENDPOINT = $VISION_ENDPOINT"
echo ""
echo "3. Or set Azure DevOps Variables for deployment script:"
echo "   - ACR_NAME = $ACR_NAME"
echo "   - STORAGE_ACCOUNT_NAME = $STORAGE_ACCOUNT_NAME"
echo "   - COSMOS_ACCOUNT_NAME = $COSMOS_ACCOUNT_NAME"
echo "   - COSMOS_ENDPOINT = $COSMOS_ENDPOINT"
echo "   - VISION_ENDPOINT = $VISION_ENDPOINT"
echo ""
echo "3. Configure app settings (values will be set by deploy script with Managed Identity):"
echo "   - Azure__Storage__AccountName = $STORAGE_ACCOUNT_NAME"
echo "   - Azure__Storage__ContainerName = user-libraries"
echo "   - Azure__CosmosDb__Endpoint = $COSMOS_ENDPOINT"
echo "   - Azure__CosmosDb__DatabaseName = LibraryDb"
echo "   - Azure__CosmosDb__ContainerName = Books"
echo "   - Azure__Vision__Endpoint = $VISION_ENDPOINT"
echo ""
echo "4. Build and push your Docker image:"
echo "   az acr build -r $ACR_NAME -t virtual-library-api:latest ."
echo ""
echo "5. Deploy the Web App:"
echo "   RG=$RG LOCATION=$LOCATION PLAN_NAME=$PLAN_NAME WEBAPP_NAME=$WEBAPP_NAME \\"
echo "   ACR_NAME=$ACR_NAME ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io \\"
echo "   IMAGE_NAME=virtual-library-api IMAGE_TAG=latest \\"
echo "   COSMOS_ENDPOINT=$COSMOS_ENDPOINT \\"
echo "   STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME STORAGE_CONTAINER_NAME=user-libraries \\"
echo "   VISION_ENDPOINT=$VISION_ENDPOINT ./scripts/deploy-webapp.sh"
echo ""
echo -e "${YELLOW}Web App URL:${NC}"
echo "   https://$WEBAPP_NAME.azurewebsites.net"
echo ""
