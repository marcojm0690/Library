#!/usr/bin/env bash
set -euo pipefail

# Purpose: Provision/update Azure Web App for Containers and deploy image from ACR using Managed Identity
# Requirements: Azure CLI logged in, subscription selected
# Usage (example):
#   RG=VirtualLibraryRG \
#   LOCATION=eastus \
#   PLAN_NAME=vl-asp-linux \
#   WEBAPP_NAME=virtual-library-api-web \
#   ACR_NAME=virtuallibraryacr \
#   ACR_LOGIN_SERVER=virtuallibraryacr.azurecr.io \
#   IMAGE_NAME=virtual-library-api \
#   IMAGE_TAG=$(git rev-parse HEAD) \
#   STORAGE_ACCOUNT_NAME=yourstorageaccount \
#   STORAGE_CONTAINER_NAME=user-libraries \
#   COSMOS_ACCOUNT_NAME=virtuallibrary-server \
#   COSMOS_ENDPOINT="https://virtuallibrary-server.documents.azure.com:443/" \
#   COSMOS_DB_NAME=LibraryDb \
#   COSMOS_CONTAINER_NAME=Books \
#   VISION_ENDPOINT="https://YOUR_REGION.api.cognitive.microsoft.com/" \
#   ./scripts/deploy-webapp.sh

: "${RG:?RG required}"
: "${LOCATION:?LOCATION required}"
: "${PLAN_NAME:?PLAN_NAME required}"
: "${WEBAPP_NAME:?WEBAPP_NAME required}"
: "${ACR_NAME:?ACR_NAME required}"
: "${ACR_LOGIN_SERVER:?ACR_LOGIN_SERVER required}"
: "${IMAGE_NAME:?IMAGE_NAME required}"
: "${IMAGE_TAG:?IMAGE_TAG required}"

# Required app settings
: "${STORAGE_ACCOUNT_NAME:?STORAGE_ACCOUNT_NAME required}"
: "${STORAGE_CONTAINER_NAME:?STORAGE_CONTAINER_NAME required}"
: "${COSMOS_ACCOUNT_NAME:?COSMOS_ACCOUNT_NAME required}"
: "${COSMOS_ENDPOINT:?COSMOS_ENDPOINT required}"
: "${COSMOS_DB_NAME:?COSMOS_DB_NAME required}"
: "${COSMOS_CONTAINER_NAME:?COSMOS_CONTAINER_NAME required}"
: "${VISION_ENDPOINT:?VISION_ENDPOINT required}"

FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

# Create RG and Plan if not exists
az group create -n "$RG" -l "$LOCATION" --only-show-errors
az appservice plan create -g "$RG" -n "$PLAN_NAME" --is-linux --sku B1 --only-show-errors || true

# Create Web App if not exists
if ! az webapp show -g "$RG" -n "$WEBAPP_NAME" >/dev/null 2>&1; then
  echo "Creating Web App ${WEBAPP_NAME}..."
  az webapp create -g "$RG" -p "$PLAN_NAME" -n "$WEBAPP_NAME" --deployment-container-image-name "$FULL_IMAGE" --only-show-errors
fi

# Enable system-assigned managed identity
echo "Enabling managed identity..."
PRINCIPAL_ID=$(az webapp identity assign -g "$RG" -n "$WEBAPP_NAME" --query principalId -o tsv)

# Grant ACR Pull role to managed identity
echo "Granting AcrPull role to managed identity..."
ACR_ID=$(az acr show -n "$ACR_NAME" --query id -o tsv)
az role assignment create --assignee "$PRINCIPAL_ID" --role AcrPull --scope "$ACR_ID" --only-show-errors || true

# Grant Storage Blob Data Contributor role
echo "Granting Storage Blob Data Contributor role..."
STORAGE_ID=$(az storage account show -n "$STORAGE_ACCOUNT_NAME" -g "$RG" --query id -o tsv)
az role assignment create --assignee "$PRINCIPAL_ID" --role "Storage Blob Data Contributor" --scope "$STORAGE_ID" --only-show-errors || true

# Grant Cognitive Services User role (for Vision API)
echo "Granting Cognitive Services User role..."
VISION_RESOURCE_NAME=$(echo "$VISION_ENDPOINT" | sed -E 's|https://([^.]+).*|\1|')
VISION_ID=$(az cognitiveservices account show -n "$VISION_RESOURCE_NAME" -g "$RG" --query id -o tsv 2>/dev/null || echo "")
if [ -n "$VISION_ID" ]; then
  az role assignment create --assignee "$PRINCIPAL_ID" --role "Cognitive Services User" --scope "$VISION_ID" --only-show-errors || true
fi

# Grant Cosmos DB Built-in Data Contributor role
echo "Granting Cosmos DB Built-in Data Contributor role..."
COSMOS_ID=$(az cosmosdb show -n "$COSMOS_ACCOUNT_NAME" -g "$RG" --query id -o tsv 2>/dev/null || echo "")
if [ -n "$COSMOS_ID" ]; then
  az role assignment create --assignee "$PRINCIPAL_ID" --role "Cosmos DB Built-in Data Contributor" --scope "$COSMOS_ID" --only-show-errors || true
fi

# Configure container to use managed identity for ACR
az webapp config set -g "$RG" -n "$WEBAPP_NAME" --generic-configurations '{"acrUseManagedIdentityCreds": true}' --only-show-errors

# Update container image
az webapp config container set \
  -g "$RG" -n "$WEBAPP_NAME" \
  --docker-custom-image-name "$FULL_IMAGE" \
  --docker-registry-server-url "https://${ACR_LOGIN_SERVER}" \
  --only-show-errors

# Set required app settings (double-underscore for nested config)
az webapp config appsettings set -g "$RG" -n "$WEBAPP_NAME" --settings \
  WEBSITES_PORT=8080 \
  ASPNETCORE_ENVIRONMENT=Production \
  Azure__Storage__AccountName="${STORAGE_ACCOUNT_NAME}" \
  Azure__Storage__ContainerName="${STORAGE_CONTAINER_NAME}" \
  Azure__CosmosDb__Endpoint="${COSMOS_ENDPOINT}" \
  Azure__CosmosDb__DatabaseName="${COSMOS_DB_NAME}" \
  Azure__CosmosDb__ContainerName="${COSMOS_CONTAINER_NAME}" \
  Azure__Vision__Endpoint="${VISION_ENDPOINT}" \
  --only-show-errors

# Restart to apply
az webapp restart -g "$RG" -n "$WEBAPP_NAME" --only-show-errors

echo "Deployed ${FULL_IMAGE} to Web App ${WEBAPP_NAME}"
