#!/usr/bin/env bash
set -euo pipefail

# Purpose: Provision/update Azure Web App for Containers and deploy image from ACR
# Requirements: Azure CLI logged in, subscription selected, ACR admin enabled or MI with ACR Pull
# Usage (example):
#   RG=VirtualLibraryRG \
#   LOCATION=eastus \
#   PLAN_NAME=vl-asp-linux \
#   WEBAPP_NAME=virtual-library-api-web \
#   ACR_LOGIN_SERVER=virtuallibraryacr.azurecr.io \
#   IMAGE_NAME=virtual-library-api \
#   IMAGE_TAG=$(git rev-parse HEAD) \
#   ACR_USERNAME=$ACR_USERNAME \
#   ACR_PASSWORD=$ACR_PASSWORD \
#   AZURE_STORAGE_CONNECTION_STRING="..." \
#   AZURE_STORAGE_CONTAINER_NAME="user-libraries" \
#   AZURE_VISION_ENDPOINT="https://YOUR_REGION.api.cognitive.microsoft.com/" \
#   AZURE_VISION_APIKEY="YOUR_API_KEY" \
#   ./scripts/deploy-webapp.sh

: "${RG:?RG required}"
: "${LOCATION:?LOCATION required}"
: "${PLAN_NAME:?PLAN_NAME required}"
: "${WEBAPP_NAME:?WEBAPP_NAME required}"
: "${ACR_LOGIN_SERVER:?ACR_LOGIN_SERVER required}"
: "${IMAGE_NAME:?IMAGE_NAME required}"
: "${IMAGE_TAG:?IMAGE_TAG required}"
: "${ACR_USERNAME:?ACR_USERNAME required}"
: "${ACR_PASSWORD:?ACR_PASSWORD required}"

# Optional app settings (recommended)
: "${AZURE_STORAGE_CONNECTION_STRING:?AZURE_STORAGE_CONNECTION_STRING required}"
: "${AZURE_STORAGE_CONTAINER_NAME:?AZURE_STORAGE_CONTAINER_NAME required}"
: "${AZURE_VISION_ENDPOINT:?AZURE_VISION_ENDPOINT required}"
: "${AZURE_VISION_APIKEY:?AZURE_VISION_APIKEY required}"

FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

# Create RG and Plan if not exists
az group create -n "$RG" -l "$LOCATION" --only-show-errors
az appservice plan create -g "$RG" -n "$PLAN_NAME" --is-linux --sku B1 --only-show-errors || true

# Create Web App if not exists
if ! az webapp show -g "$RG" -n "$WEBAPP_NAME" >/dev/null 2>&1; then
  az webapp create -g "$RG" -p "$PLAN_NAME" -n "$WEBAPP_NAME" --runtime "DOTNETCORE|10.0" --only-show-errors
fi

# Configure container image from ACR
az webapp config container set \
  -g "$RG" -n "$WEBAPP_NAME" \
  --docker-custom-image-name "$FULL_IMAGE" \
  --docker-registry-server-url "https://${ACR_LOGIN_SERVER}" \
  --docker-registry-server-user "$ACR_USERNAME" \
  --docker-registry-server-password "$ACR_PASSWORD" \
  --only-show-errors

# Set required app settings (double-underscore for nested config)
az webapp config appsettings set -g "$RG" -n "$WEBAPP_NAME" --settings \
  WEBSITES_PORT=8080 \
  ASPNETCORE_ENVIRONMENT=Production \
  Azure__Storage__ConnectionString="${AZURE_STORAGE_CONNECTION_STRING}" \
  Azure__Storage__ContainerName="${AZURE_STORAGE_CONTAINER_NAME}" \
  Azure__Vision__Endpoint="${AZURE_VISION_ENDPOINT}" \
  Azure__Vision__ApiKey="${AZURE_VISION_APIKEY}" \
  --only-show-errors

# Restart to apply
az webapp restart -g "$RG" -n "$WEBAPP_NAME" --only-show-errors

echo "Deployed ${FULL_IMAGE} to Web App ${WEBAPP_NAME}"
