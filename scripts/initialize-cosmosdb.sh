#!/usr/bin/env bash
set -euo pipefail

# Purpose: Initialize Cosmos DB database and container for Virtual Library API
# Requirements: Azure CLI logged in, subscription selected, Cosmos DB account must exist
# Usage (example):
#   COSMOS_ACCOUNT_NAME=virtuallibrary-server \
#   COSMOS_RESOURCE_GROUP=VirtualLibraryRG \
#   COSMOS_DATABASE_NAME=LibraryDb \
#   COSMOS_CONTAINER_NAME=Books \
#   ./scripts/initialize-cosmosdb.sh

: "${COSMOS_ACCOUNT_NAME:?COSMOS_ACCOUNT_NAME required (e.g., virtuallibrary-server)}"
: "${COSMOS_RESOURCE_GROUP:?COSMOS_RESOURCE_GROUP required (e.g., VirtualLibraryRG)}"
: "${COSMOS_DATABASE_NAME:=LibraryDb}"
: "${COSMOS_CONTAINER_NAME:=Books}"
: "${COSMOS_PARTITION_KEY:=/id}"
: "${COSMOS_RU:=400}"

echo "=========================================="
echo "Cosmos DB Initialization"
echo "=========================================="
echo "Account: $COSMOS_ACCOUNT_NAME"
echo "Resource Group: $COSMOS_RESOURCE_GROUP"
echo "Database: $COSMOS_DATABASE_NAME"
echo "Container: $COSMOS_CONTAINER_NAME"
echo "Partition Key: $COSMOS_PARTITION_KEY"
echo "RUs: $COSMOS_RU"
echo ""

# Verify account exists
echo "Verifying Cosmos DB account exists..."
if ! az cosmosdb show \
  -n "$COSMOS_ACCOUNT_NAME" \
  -g "$COSMOS_RESOURCE_GROUP" \
  >/dev/null 2>&1; then
  echo "ERROR: Cosmos DB account '$COSMOS_ACCOUNT_NAME' not found in resource group '$COSMOS_RESOURCE_GROUP'"
  exit 1
fi
echo "✓ Cosmos DB account verified"

# Create database if not exists
echo ""
echo "Creating database '$COSMOS_DATABASE_NAME' if it doesn't exist..."
if az cosmosdb sql database exists \
  -g "$COSMOS_RESOURCE_GROUP" \
  -a "$COSMOS_ACCOUNT_NAME" \
  -n "$COSMOS_DATABASE_NAME" \
  --only-show-errors 2>/dev/null | grep -q "true"; then
  echo "✓ Database already exists"
else
  az cosmosdb sql database create \
    -g "$COSMOS_RESOURCE_GROUP" \
    -a "$COSMOS_ACCOUNT_NAME" \
    -n "$COSMOS_DATABASE_NAME" \
    --only-show-errors
  echo "✓ Database created"
fi

# Create container if not exists
echo ""
echo "Creating container '$COSMOS_CONTAINER_NAME' if it doesn't exist..."
if az cosmosdb sql container exists \
  -g "$COSMOS_RESOURCE_GROUP" \
  -a "$COSMOS_ACCOUNT_NAME" \
  -d "$COSMOS_DATABASE_NAME" \
  -n "$COSMOS_CONTAINER_NAME" \
  --only-show-errors 2>/dev/null | grep -q "true"; then
  echo "✓ Container already exists"
else
  az cosmosdb sql container create \
    -g "$COSMOS_RESOURCE_GROUP" \
    -a "$COSMOS_ACCOUNT_NAME" \
    -d "$COSMOS_DATABASE_NAME" \
    -n "$COSMOS_CONTAINER_NAME" \
    -p "$COSMOS_PARTITION_KEY" \
    --throughput "$COSMOS_RU" \
    --only-show-errors
  echo "✓ Container created with $COSMOS_RU RUs"
fi

# Get Cosmos DB endpoint for configuration
echo ""
echo "Retrieving Cosmos DB endpoint..."
COSMOS_ENDPOINT=$(az cosmosdb show \
  -n "$COSMOS_ACCOUNT_NAME" \
  -g "$COSMOS_RESOURCE_GROUP" \
  --query documentEndpoint \
  -o tsv)

echo ""
echo "=========================================="
echo "Initialization Complete!"
echo "=========================================="
echo ""
echo "Configuration for deployment:"
echo "  COSMOS_ACCOUNT_NAME=$COSMOS_ACCOUNT_NAME"
echo "  COSMOS_ENDPOINT=$COSMOS_ENDPOINT"
echo "  COSMOS_DB_NAME=$COSMOS_DATABASE_NAME"
echo "  COSMOS_CONTAINER_NAME=$COSMOS_CONTAINER_NAME"
echo ""
echo "Use these values in the deployment script:"
echo "  ./scripts/deploy-webapp.sh \\"
echo "    ... \\"
echo "    COSMOS_ACCOUNT_NAME='$COSMOS_ACCOUNT_NAME' \\"
echo "    COSMOS_ENDPOINT='$COSMOS_ENDPOINT' \\"
echo "    COSMOS_DB_NAME='$COSMOS_DATABASE_NAME' \\"
echo "    COSMOS_CONTAINER_NAME='$COSMOS_CONTAINER_NAME' \\"
echo "    ..."
echo ""
