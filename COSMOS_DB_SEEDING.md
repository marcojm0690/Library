# Cosmos DB Mock Data Seeding Guide

## Overview

Mock book data is now automatically seeded into Cosmos DB when configured. The seeder is **idempotent** - it safely runs multiple times without creating duplicates.

---

## How It Works

1. **Checks if container is empty** - Only seeds if no books exist
2. **Seeds 10 sample books** - Various genres (programming, fiction, science, business)
3. **Safe to run repeatedly** - Won't duplicate existing data
4. **Graceful error handling** - Continues if one book fails

---

## Enable Seeding

### Local Development (Recommended)
Seeding is **already enabled** in `appsettings.Development.json`:

```json
"Azure": {
  "CosmosDb": {
    "SeedMockData": true
  }
}
```

When you run `dotnet run`, mock data will be automatically seeded on startup.

### Production Environment
Seeding is **disabled** by default in `appsettings.json`:

```json
"Azure": {
  "CosmosDb": {
    "SeedMockData": false
  }
}
```

To enable in production, override via environment variable:
```bash
export Azure__CosmosDb__SeedMockData=true
```

---

## Run Locally

### Option 1: With In-Memory Database (No Azure)

```bash
cd virtual-library/api/VirtualLibrary.Api
dotnet run
```

This uses `InMemoryBookRepository` (mock data NOT applied, but you can test without Azure).

---

### Option 2: With Cosmos DB Emulator

1. **Install Cosmos DB Emulator**
   ```bash
   # macOS with Homebrew
   brew install cosmosdb-emulator
   
   # Or download from: https://aka.ms/cosmosdb-emulator
   ```

2. **Start the emulator**
   ```bash
   # Run emulator in separate terminal
   cosmosdb-emulator
   ```

3. **Update appsettings.Development.json**
   ```json
   "Azure": {
     "CosmosDb": {
       "Endpoint": "https://localhost:8081/",
       "DatabaseName": "LibraryDb",
       "ContainerName": "Books",
       "SeedMockData": true
     }
   }
   ```

4. **Run the app**
   ```bash
   cd virtual-library/api/VirtualLibrary.Api
   dotnet run
   ```

   The app will:
   - ✓ Connect to local Cosmos DB emulator
   - ✓ Create database and container (if missing)
   - ✓ Seed 10 sample books
   - ✓ Log: "Seeding completed successfully."

5. **Query the data**
   ```bash
   curl http://localhost:5000/api/books
   ```

   Returns all 10 seeded books as JSON.

---

### Option 3: With Real Azure Cosmos DB

1. **Ensure Cosmos DB account exists**
   ```bash
   az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG \
     --query '{name:.name, state:.properties.provisioningState}' -o table
   ```

2. **Initialize database/container**
   ```bash
   COSMOS_ACCOUNT_NAME=virtuallibrary-server \
   COSMOS_RESOURCE_GROUP=VirtualLibraryRG \
   ./scripts/initialize-cosmosdb.sh
   ```

3. **Get Cosmos DB endpoint**
   ```bash
   COSMOS_ENDPOINT=$(az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG \
     --query documentEndpoint -o tsv)
   echo $COSMOS_ENDPOINT
   ```

4. **Update appsettings.Development.json**
   ```json
   "Azure": {
     "CosmosDb": {
       "Endpoint": "YOUR_COSMOS_ENDPOINT",
       "DatabaseName": "LibraryDb",
       "ContainerName": "Books",
       "SeedMockData": true
     }
   }
   ```

5. **Run the app with Azure identity**
   ```bash
   # Authenticate with Azure
   az login
   
   # Run app (will use your Azure credentials)
   cd virtual-library/api/VirtualLibrary.Api
   dotnet run
   ```

   Output logs:
   ```
   Checking if Cosmos DB needs seeding...
   Cosmos DB is empty. Seeding mock data...
   Seeded book: The C# Player's Guide by RB Whitaker
   Seeded book: Clean Code by Robert C. Martin
   ...
   Seeding completed successfully.
   ```

---

## What Gets Seeded

10 sample books across different genres:

### Programming Books
- **The C# Player's Guide** - RB Whitaker (2019)
- **Clean Code** - Robert C. Martin (2008)
- **Code Complete** - Steve McConnell (2004)
- **The Pragmatic Programmer** - Andrew Hunt, David Thomas (2000)

### Fiction
- **To Kill a Mockingbird** - Harper Lee (1960)
- **1984** - George Orwell (1949)

### Science
- **A Brief History of Time** - Stephen Hawking (1988)
- **Cosmos** - Carl Sagan (1980)

### Business
- **Good to Great** - Jim Collins (2001)
- **The Lean Startup** - Eric Ries (2011)

Each book includes:
- Unique ID (GUID)
- ISBN
- Title & Authors
- Publisher & Publish Year
- Page Count
- Cover Image URL
- Description
- Source (marked as "MockData")

---

## Test Seeded Data

### View All Books
```bash
curl http://localhost:5000/api/books
```

### Search by Title
```bash
curl "http://localhost:5000/api/books/search?query=C%23"
```

Response: Returns "The C# Player's Guide" and "Code Complete"

### Search by Author
```bash
curl "http://localhost:5000/api/books/search?query=Martin"
```

Response: Returns "Clean Code"

### Search by ISBN
```bash
curl "http://localhost:5000/api/books/isbn/978-0-13-235088-4"
```

Response: Returns "Clean Code"

---

## Disable/Clear Seeding

### Disable Auto-Seeding
Edit `appsettings.Development.json`:
```json
"SeedMockData": false
```

The app will NOT seed on startup, but existing data remains.

### Clear Seeded Data
To remove all seeded books from Cosmos DB:

**Via Cosmos DB Portal:**
1. Go to Azure Portal → Cosmos DB account
2. Select "Data Explorer"
3. Right-click "Books" container → Delete
4. Recreate container with same name
5. Re-run app with `SeedMockData: true` to reseed

**Via Azure CLI:**
```bash
az cosmosdb sql container delete \
  -g VirtualLibraryRG \
  -a virtuallibrary-server \
  -d LibraryDb \
  -n Books

# Then run app - will recreate and reseed
```

---

## Troubleshooting

### "Cosmos DB is empty" but no seeding happens
**Issue**: `SeedMockData` is false
**Solution**: Set `SeedMockData: true` in appsettings.Development.json

### "Failed to initialize Cosmos DB repository"
**Issue**: Cosmos DB account not created yet
**Solution**: 
```bash
# Check status
az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG --query properties.provisioningState
# Wait if "Provisioning"
# Initialize when "Succeeded"
./scripts/initialize-cosmosdb.sh
```

### "Error seeding book"
**Issue**: Network/authentication problem
**Solution**: Check logs:
```bash
# If running locally, look at console output
# If on Azure Web App:
az webapp log tail -g VirtualLibraryRG -n virtual-library-api-web
```

### Books not showing in API
**Issue**: Seeding ran, but API returns empty
**Solution**: 
```bash
# Check Cosmos DB Data Explorer in Azure Portal
# Verify container has documents
# Or query directly:
az cosmosdb sql query \
  -g VirtualLibraryRG \
  -a virtuallibrary-server \
  -d LibraryDb \
  -c Books \
  -q "SELECT COUNT(*) as BookCount FROM c"
```

---

## Add More Mock Books

Edit `CosmosDbSeeder.cs` and add to `GetMockBooks()` list:

```csharp
private static List<Book> GetMockBooks()
{
    return new List<Book>
    {
        // Existing books...
        
        // Add your own:
        new Book
        {
            Id = Guid.NewGuid(),
            Isbn = "978-YOUR-ISBN",
            Title = "Your Book Title",
            Authors = new List<string> { "Author Name" },
            Publisher = "Publisher Name",
            PublishYear = 2024,
            PageCount = 300,
            Description = "Book description",
            Source = "MockData"
        }
    };
}
```

Then rebuild and run - seeder will add your books when container is empty.

---

## Summary

✅ **10 sample books automatically seeded**
✅ **Works locally, with emulator, or Azure**
✅ **Safe to run multiple times**
✅ **Easy to customize with your own books**
✅ **Disabled by default in production**
