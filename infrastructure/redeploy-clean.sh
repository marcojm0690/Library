#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="biblioteca"
LOCATION="canadacentral"
COSMOS_ACCOUNT="virtual-library-server"
WEBAPP_NAME="virtual-library-api-web"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🧹 Azure Resources Cleanup & Redeploy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Stop web app
echo -e "${YELLOW}📍 Step 1: Stopping web app...${NC}"
az webapp stop --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" || true
echo -e "${GREEN}✅ Web app stopped${NC}"
echo ""

# Step 2: Delete Cosmos DB collections to prepare for upgrade
echo -e "${YELLOW}📍 Step 2: Cleaning Cosmos DB collections...${NC}"
az cosmosdb mongodb collection delete \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name LibraryDb \
  --name Books \
  --yes || echo "Collection 'Books' not found or already deleted"

az cosmosdb mongodb collection delete \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name LibraryDb \
  --name Libraries \
  --yes || echo "Collection 'Libraries' not found or already deleted"

echo -e "${GREEN}✅ Collections cleaned${NC}"
echo ""

# Step 3: Update Cosmos DB to MongoDB 4.2
echo -e "${YELLOW}📍 Step 3: Upgrading Cosmos DB to MongoDB 4.2...${NC}"
echo -e "${BLUE}ℹ️  Note: This may take 15-30 minutes. The upgrade is irreversible.${NC}"

az cosmosdb update \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --capabilities EnableMongo \
  --server-version 4.2

echo -e "${GREEN}✅ Cosmos DB upgraded to MongoDB 4.2${NC}"
echo ""

# Step 4: Redeploy infrastructure with Bicep
echo -e "${YELLOW}📍 Step 4: Redeploying infrastructure with Bicep...${NC}"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infrastructure/main.bicep \
  --parameters infrastructure/parameters.json \
  --mode Incremental

echo -e "${GREEN}✅ Infrastructure redeployed${NC}"
echo ""

# Step 5: Build and push new Docker image
echo -e "${YELLOW}📍 Step 5: Building new Docker image...${NC}"
IMAGE_TAG="v4.2-$(date +%Y%m%d-%H%M%S)"
docker build -t virtuallibraryacr.azurecr.io/virtual-library-api:$IMAGE_TAG -f Dockerfile .

echo -e "${YELLOW}📍 Step 6: Pushing to ACR...${NC}"
az acr login --name virtuallibraryacr
docker push virtuallibraryacr.azurecr.io/virtual-library-api:$IMAGE_TAG

# Also tag as latest
docker tag virtuallibraryacr.azurecr.io/virtual-library-api:$IMAGE_TAG \
           virtuallibraryacr.azurecr.io/virtual-library-api:latest
docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest

echo -e "${GREEN}✅ Docker image built and pushed${NC}"
echo ""

# Step 7: Update web app with new image
echo -e "${YELLOW}📍 Step 7: Updating web app container...${NC}"
az webapp config container set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --docker-custom-image-name virtuallibraryacr.azurecr.io/virtual-library-api:$IMAGE_TAG

echo -e "${GREEN}✅ Web app updated${NC}"
echo ""

# Step 8: Start web app
echo -e "${YELLOW}📍 Step 8: Starting web app...${NC}"
az webapp start --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP"
echo -e "${GREEN}✅ Web app started${NC}"
echo ""

# Step 9: Wait for app to warm up
echo -e "${YELLOW}📍 Step 9: Waiting for app to warm up (30 seconds)...${NC}"
sleep 30

# Step 10: Test the endpoint
echo -e "${YELLOW}📍 Step 10: Testing the API...${NC}"
WEBAPP_URL="https://${WEBAPP_NAME}.azurewebsites.net"
echo -e "${BLUE}Testing: ${WEBAPP_URL}/api/libraries/owner/373876A5-706A-4E40-B034-6D60B2FFCD25${NC}"
curl -s "${WEBAPP_URL}/api/libraries/owner/373876A5-706A-4E40-B034-6D60B2FFCD25" | jq . || echo "API returned an error (check logs)"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  🌍 Web App URL: ${WEBAPP_URL}"
echo -e "  🐳 Docker Image: virtuallibraryacr.azurecr.io/virtual-library-api:${IMAGE_TAG}"
echo -e "  🗄️  MongoDB Version: 4.2"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "  1. Check logs: az webapp log tail --name ${WEBAPP_NAME} --resource-group ${RESOURCE_GROUP}"
echo -e "  2. Test Swagger: ${WEBAPP_URL}/swagger"
echo -e "  3. Monitor: az monitor metrics list --resource ${WEBAPP_NAME}"
echo ""
