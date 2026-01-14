# Seeding Cosmos DB in Azure

## Overview

The Virtual Library API has **dual seeding capabilities**:

1. **In-Memory Development** - Auto-seeds 10 mock books when running locally without Cosmos DB
2. **Cloud Production** - Seeds Cosmos DB when deployed to Azure

## Prerequisites

- Azure Cosmos DB account created in Azure (`virtuallibrary-server` in `VirtualLibraryRG`)
- Database and container initialized
- App configured with Cosmos DB endpoint
- Managed Identity with Cosmos DB Data Contributor role

## Step 1: Create Cosmos DB Account (Manual via Azure Portal)

Due to API issues with Azure CLI, create the account manually:

1. Go to [Azure Portal](https://portal.azure.com)
2. Create new resource: **Azure Cosmos DB**
3. Configure:
   - **Account Name**: `virtuallibrary-server`
   - **Resource Group**: `VirtualLibraryRG`
   - **Location**: `Canada Central`
   - **API**: Core (SQL)
   - **Capacity Mode**: Provisioned (400 RU/s)
4. Click **Create** and wait 10-15 minutes

## Step 2: Initialize Database & Container

Once the account is created:

```bash
# Get the Cosmos DB endpoint
COSMOS_ENDPOINT=$(az cosmosdb show -n virtuallibrary-server \
  -g VirtualLibraryRG --query documentEndpoint -o tsv)

# Get a key
COSMOS_KEY=$(az cosmosdb keys list -n virtuallibrary-server \
  -g VirtualLibraryRG --type keys --query primaryMasterKey -o tsv)

# Use the initialize script
bash scripts/initialize-cosmosdb.sh
```

Or manually via Azure Portal:
1. Open Cosmos DB account
2. Go to **Data Explorer**
3. Create Database: `LibraryDb`
4. Create Container: `Books` with Partition Key: `/id`

## Step 3: Update App Configuration

Update your app settings with the real Cosmos DB endpoint:

**appsettings.json** (or via environment variables in Azure):
```json
{
  "Azure": {
    "CosmosDb": {
      "Endpoint": "https://virtuallibrary-server.documents.azure.com:443/",
      "DatabaseName": "LibraryDb",
      "ContainerName": "Books",
      "SeedMockData": true
    }
  }
}
```

## Step 4: Deploy App with Seeding

When the app starts with Cosmos DB configured:

1. **First startup**: Checks if `Books` container is empty
2. **If empty**: Seeds with 10 mock books automatically
3. **If not empty**: Skips seeding (idempotent - safe to restart)

### Option A: Deploy via Azure App Service

```bash
cd /Users/marco.jimenez/Documents/Projects/Library/virtual-library/api/VirtualLibrary.Api

# Publish to Azure
dotnet publish -c Release -o ./publish

# Deploy using CLI
az webapp deployment source config-zip \
  --resource-group VirtualLibraryRG \
  --name virtuallibrary-api \
  --src-path publish.zip
```

### Option B: Deploy via Docker

```bash
# Build Docker image
docker build -t virtuallibrary-api:latest \
  -f Dockerfile \
  .

# Push to Azure Container Registry
az acr build --registry virtuallibrary \
  --image virtuallibrary-api:latest .

# Deploy to Container Instances or App Service
az container create \
  --resource-group VirtualLibraryRG \
  --name virtuallibrary-api \
  --image virtuallibrary.azurecr.io/virtuallibrary-api:latest \
  --environment-variables \
    "Azure__CosmosDb__Endpoint=https://virtuallibrary-server.documents.azure.com:443/" \
    "Azure__CosmosDb__SeedMockData=true"
```

### Option C: Deploy via Azure Pipelines

The `azure-pipelines.yml` already supports this - just configure the pipeline with:
- `COSMOS_DB_ENDPOINT`
- `RESOURCE_GROUP_NAME`
- `APP_SERVICE_NAME`

## Step 5: Verify Seeding

Once deployed, check Cosmos DB was seeded:

```bash
# Via Azure Portal:
# 1. Open Cosmos DB account → Data Explorer
# 2. Select LibraryDb → Books container
# 3. View Items - should see 10 books

# Via Azure CLI:
az cosmosdb sql query \
  -a virtuallibrary-server \
  -d LibraryDb \
  -c Books \
  -g VirtualLibraryRG \
  -q "SELECT COUNT(*) FROM c"
```

Expected output: Count = 10

## Step 6: Test API Endpoints

```bash
# Get all books
curl https://virtuallibrary-api.azurewebsites.net/api/books

# Search by ISBN
curl "https://virtuallibrary-api.azurewebsites.net/api/books/isbn/978-0-13-235088-4"

# Search by title
curl "https://virtuallibrary-api.azurewebsites.net/api/books/search?query=Clean%20Code"
```

## The 10 Seeded Books

### Programming (4)
1. **The C# Player's Guide** by RB Whitaker (2019)
2. **Clean Code** by Robert C. Martin (2008)
3. **Code Complete** by Steve McConnell (2004)
4. **The Pragmatic Programmer** by Andrew Hunt, David Thomas (2000)

### Fiction (2)
5. **To Kill a Mockingbird** by Harper Lee (1960)
6. **1984** by George Orwell (1949)

### Science (2)
7. **A Brief History of Time** by Stephen Hawking (1988)
8. **Cosmos** by Carl Sagan (1980)

### Business (2)
9. **Good to Great** by Jim Collins (2001)
10. **The Lean Startup** by Eric Ries (2011)

## Seeding Implementation Details

**Location**: [CosmosDbSeeder.cs](virtual-library/api/VirtualLibrary.Api/Infrastructure/Persistence/CosmosDbSeeder.cs)

**Key Features**:
- ✅ Idempotent - checks if container empty before seeding
- ✅ Async - non-blocking startup
- ✅ Error handling - logs warnings if seeding fails, continues startup
- ✅ Configurable - respects `SeedMockData` setting
- ✅ Automatic - runs on first startup when container is empty

**Code Flow**:
```csharp
// Program.cs startup
if (Cosmos DB configured && SeedMockData enabled)
{
    var seeder = serviceProvider.GetRequiredService<CosmosDbSeeder>();
    await seeder.SeedIfEmptyAsync();  // Only seeds if container empty
}
```

## Troubleshooting

### Cosmos DB Account Not Found
```bash
# Verify account exists
az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG

# If not found, create it via Azure Portal
```

### Seeding Not Running
Check logs in App Service:
```bash
az webapp log tail --resource-group VirtualLibraryRG --name virtuallibrary-api
```

Look for: `"Seeding mock data to Cosmos DB..."` or error messages

### Books Not In Database
1. Verify database/container created in Data Explorer
2. Check Cosmos DB firewall rules allow App Service
3. Verify Managed Identity has "Cosmos DB Data Contributor" role
4. Restart app service to trigger seeding

### API Returns 404 for Books
- In-memory development: Ensure app runs in Development environment
- Cloud deployment: Verify Cosmos DB contains 10 items (check Data Explorer)

## Local Development (In-Memory)

For testing without Azure:

```bash
# Set Cosmos DB endpoint to empty in appsettings.Development.json
"Azure": {
  "CosmosDb": {
    "Endpoint": ""  // Empty = use in-memory with auto-seeding
  }
}

# Run app
dotnet run

# Test
curl http://localhost:5000/api/books
```

## Next Steps

1. ✅ In-memory seeding ready now - test with `dotnet run`
2. ⏳ Create Cosmos DB account in Azure Portal
3. ⏳ Initialize database/container
4. ⏳ Update appsettings with real endpoint
5. ⏳ Deploy to Azure
6. ⏳ Verify seeding in Cosmos DB
