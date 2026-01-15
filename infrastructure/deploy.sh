#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Virtual Library - Infrastructure Deployment${NC}"
echo "==========================================="

# Configuration
RESOURCE_GROUP="${RG:-biblioteca}"
LOCATION="${LOCATION:-canadacentral}"
TEMPLATE_FILE="infrastructure/main.bicep"
PARAMETERS_FILE="infrastructure/parameters.json"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Template: $TEMPLATE_FILE"
echo ""

# Ensure resource group exists
echo -e "${YELLOW}Creating resource group if it doesn't exist...${NC}"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --only-show-errors
echo -e "${GREEN}✓ Resource group ready${NC}"

# Validate template
echo -e "${YELLOW}Validating Bicep template...${NC}"
az deployment group validate \
  -g "$RESOURCE_GROUP" \
  -f "$TEMPLATE_FILE" \
  -p "$PARAMETERS_FILE" \
  --only-show-errors
echo -e "${GREEN}✓ Template validation passed${NC}"

# Deploy infrastructure
echo -e "${YELLOW}Deploying infrastructure...${NC}"
DEPLOYMENT_OUTPUT=$(az deployment group create \
  -g "$RESOURCE_GROUP" \
  -f "$TEMPLATE_FILE" \
  -p "$PARAMETERS_FILE" \
  --query "properties.outputs" \
  -o json)

echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
echo ""
echo -e "${YELLOW}Deployment Outputs:${NC}"
echo "$DEPLOYMENT_OUTPUT" | jq '.' 2>/dev/null || echo "$DEPLOYMENT_OUTPUT"

# Extract key values
ACR_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.acrName.value' 2>/dev/null || echo "virtual-libraryacr")
WEB_APP_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.webAppName.value' 2>/dev/null || echo "virtual-library-api-web")
WEB_APP_URL=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.webAppUrl.value' 2>/dev/null || echo "")

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "ACR Name: $ACR_NAME"
echo "Web App Name: $WEB_APP_NAME"
echo "Web App URL: $WEB_APP_URL"
echo "Swagger UI: ${WEB_APP_URL}/swagger/index.html"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure Azure DevOps Service Connection for ACR"
echo "2. Run your CI/CD pipeline to build and push the Docker image"
echo "3. The web app will automatically pull and run the image"
echo ""
