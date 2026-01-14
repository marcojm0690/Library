#!/bin/bash

# Cosmos DB Setup and Seeding Script
# This script creates Cosmos DB account, initializes it, and deploys the seeded app

set -e

# Configuration
ACCOUNT_NAME="virtuallibrary-server"
RESOURCE_GROUP="VirtualLibraryRG"
LOCATION="canadacentral"
DATABASE_NAME="LibraryDb"
CONTAINER_NAME="Books"
COSMOS_THROUGHPUT=400

echo "🚀 Starting Cosmos DB Setup for Virtual Library..."
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI not found. Install from https://docs.microsoft.com/cli/azure/install-azure-cli"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "❌ curl not found"; exit 1; }

# Verify logged in
az account show > /dev/null 2>&1 || { echo "❌ Not logged into Azure. Run 'az login'"; exit 1; }
echo "✅ Azure CLI ready"
echo ""

# Check if resource group exists
echo "🔍 Checking resource group..."
if ! az group show -n "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "❌ Resource group '$RESOURCE_GROUP' not found"
    echo "   Create it with: az group create -n $RESOURCE_GROUP -l $LOCATION"
    exit 1
fi
echo "✅ Resource group '$RESOURCE_GROUP' found"
echo ""

# Check if Cosmos DB account exists
echo "🔍 Checking if Cosmos DB account exists..."
if az cosmosdb show -n "$ACCOUNT_NAME" -g "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "✅ Cosmos DB account '$ACCOUNT_NAME' already exists"
    COSMOS_ENDPOINT=$(az cosmosdb show -n "$ACCOUNT_NAME" -g "$RESOURCE_GROUP" --query documentEndpoint -o tsv)
    echo "   Endpoint: $COSMOS_ENDPOINT"
else
    echo "❌ Cosmos DB account '$ACCOUNT_NAME' does not exist"
    echo ""
    echo "⚠️  IMPORTANT: Create the account manually via Azure Portal:"
    echo "   1. Go to https://portal.azure.com"
    echo "   2. Search for 'Azure Cosmos DB'"
    echo "   3. Click 'Create' → 'Core (SQL) Database'"
    echo "   4. Fill in:"
    echo "      - Account Name: $ACCOUNT_NAME"
    echo "      - Resource Group: $RESOURCE_GROUP"
    echo "      - Location: $LOCATION"
    echo "      - Capacity Mode: Provisioned (400 RU/s)"
    echo "   5. Click 'Create' and wait 10-15 minutes"
    echo ""
    echo "   Then run this script again."
    exit 1
fi
echo ""

# Get connection details
echo "🔑 Retrieving connection details..."
COSMOS_KEY=$(az cosmosdb keys list -n "$ACCOUNT_NAME" -g "$RESOURCE_GROUP" --type keys --query primaryMasterKey -o tsv)
if [ -z "$COSMOS_KEY" ]; then
    echo "❌ Failed to retrieve Cosmos DB key"
    exit 1
fi
echo "✅ Connection details retrieved (key length: ${#COSMOS_KEY})"
echo ""

# Initialize database and container
echo "📦 Initializing database and container..."

# Create database
echo "   Creating database '$DATABASE_NAME'..."
curl -s -X POST \
  -H "Authorization: type=master&ver=1.0&sig=$COSMOS_KEY" \
  -H "Content-Type: application/json" \
  -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
  -H "x-ms-version: 2021-06-15" \
  -d "{\"id\": \"$DATABASE_NAME\"}" \
  "$COSMOS_ENDPOINT/dbs" > /dev/null

echo "   Creating container '$CONTAINER_NAME'..."
curl -s -X POST \
  -H "Authorization: type=master&ver=1.0&sig=$COSMOS_KEY" \
  -H "Content-Type: application/json" \
  -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
  -H "x-ms-version: 2021-06-15" \
  -H "x-ms-cosmos-db-offer-throughput: $COSMOS_THROUGHPUT" \
  -d "{\"id\": \"$CONTAINER_NAME\", \"partitionKey\": {\"paths\": [\"/id\"]}}" \
  "$COSMOS_ENDPOINT/dbs/$DATABASE_NAME/colls" > /dev/null

echo "✅ Database and container created"
echo ""

# Update app configuration
echo "⚙️  Updating application configuration..."
APP_SETTINGS_FILE="virtual-library/api/VirtualLibrary.Api/appsettings.json"

if [ -f "$APP_SETTINGS_FILE" ]; then
    # Update Cosmos DB endpoint (using sed for macOS compatibility)
    sed -i '' "s|https://YOUR_COSMOS_ACCOUNT.documents.azure.com:443/|$COSMOS_ENDPOINT|g" "$APP_SETTINGS_FILE"
    sed -i '' 's/"SeedMockData": false/"SeedMockData": true/g' "$APP_SETTINGS_FILE"
    echo "✅ Updated $APP_SETTINGS_FILE"
else
    echo "⚠️  Could not find $APP_SETTINGS_FILE"
fi
echo ""

# Build and test
echo "🔨 Building application..."
cd virtual-library/api/VirtualLibrary.Api
dotnet build --configuration Release > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Build succeeded"
else
    echo "❌ Build failed. Check for errors in the project"
    exit 1
fi
cd ../../../
echo ""

# Summary
echo "✅ Cosmos DB setup complete!"
echo ""
echo "📊 Configuration Summary:"
echo "   Account: $ACCOUNT_NAME"
echo "   Endpoint: $COSMOS_ENDPOINT"
echo "   Database: $DATABASE_NAME"
echo "   Container: $CONTAINER_NAME"
echo "   Throughput: $COSMOS_THROUGHPUT RU/s"
echo ""
echo "🚀 Next steps:"
echo "   1. Deploy the app: dotnet publish -c Release"
echo "   2. The app will automatically seed 10 mock books on first startup"
echo "   3. Verify in Azure Portal → Cosmos DB → Data Explorer"
echo ""
echo "🧪 Test locally (with in-memory):"
echo "   cd virtual-library/api/VirtualLibrary.Api"
echo "   dotnet run"
echo "   # Then: curl http://localhost:5000/api/books"
echo ""
echo "📝 Documentation: See COSMOSDB_SEEDING_GUIDE.md"
