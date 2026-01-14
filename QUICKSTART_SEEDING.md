# Quick Start: Seed Cosmos DB & Deploy

## TL;DR - 3 Steps to Production

### Step 1: Create Cosmos DB in Azure Portal (10 min)
```
1. Go to portal.azure.com
2. Search "Azure Cosmos DB" → Create
3. Account: virtuallibrary-server
   Resource Group: VirtualLibraryRG
   Location: Canada Central
   API: Core (SQL)
   Capacity: Provisioned (400 RU/s)
4. Wait for creation
```

### Step 2: Initialize Database & Container (2 min)
```bash
# Get endpoint
ENDPOINT=$(az cosmosdb show -n virtuallibrary-server \
  -g VirtualLibraryRG --query documentEndpoint -o tsv)

# Run setup script
bash setup-cosmosdb.sh
```

Or manually in Azure Portal:
- Data Explorer → Create Database "LibraryDb"
- Create Container "Books" → Partition Key: "/id"

### Step 3: Deploy App (5 min)
```bash
# Update appsettings.json with Cosmos DB endpoint
# Then publish
cd virtual-library/api/VirtualLibrary.Api
dotnet publish -c Release -o ./publish

# Deploy to Azure App Service (via portal or CLI)
```

**That's it!** The app will auto-seed 10 books on startup.

---

## Test Locally First (Right Now, 2 min)

```bash
cd virtual-library/api/VirtualLibrary.Api
dotnet run

# In another terminal
curl http://localhost:5000/api/books
```

Expected: 10 books returned in JSON

---

## Verify Cosmos DB Was Seeded

Azure Portal:
1. Open Cosmos DB account
2. Data Explorer → LibraryDb → Books
3. View Items → Should see 10 books

---

## The 10 Books That Get Seeded

| Title | Author | Year |
|-------|--------|------|
| The C# Player's Guide | RB Whitaker | 2019 |
| Clean Code | Robert C. Martin | 2008 |
| Code Complete | Steve McConnell | 2004 |
| The Pragmatic Programmer | Hunt & Thomas | 2000 |
| To Kill a Mockingbird | Harper Lee | 1960 |
| 1984 | George Orwell | 1949 |
| A Brief History of Time | Stephen Hawking | 1988 |
| Cosmos | Carl Sagan | 1980 |
| Good to Great | Jim Collins | 2001 |
| The Lean Startup | Eric Ries | 2011 |

---

## Environment-Based Behavior

### Development (appsettings.Development.json)
- Endpoint: "" (empty)
- **Uses**: InMemoryBookRepository
- **Seeding**: Auto-seeds 10 books on startup
- **Persistence**: Lost when app stops
- **Use Case**: Local testing without Azure

### Production (appsettings.json)
- Endpoint: "https://virtuallibrary-server.documents.azure.com:443/"
- **Uses**: CosmosDbBookRepository
- **Seeding**: Seeds if container empty (idempotent)
- **Persistence**: Stored in Azure Cosmos DB
- **Use Case**: Cloud deployment

---

## API Endpoints (After Seeding)

```bash
# Get all books
curl http://localhost:5000/api/books

# Get by ISBN
curl "http://localhost:5000/api/books/isbn/978-0-13-235088-4"

# Search by title
curl "http://localhost:5000/api/books/search?query=Clean%20Code"
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No books in development | Run in Development environment, Endpoint="" |
| Cosmos DB not found | Create in Azure Portal (CLI has API issues) |
| Books not in Cosmos DB | Check Data Explorer, run setup script again |
| API returns 404 | Verify Cosmos DB initialized, check connection string |
| Build fails | Run `dotnet clean && dotnet build` |

---

## Files Changed

- ✅ [Program.cs](virtual-library/api/VirtualLibrary.Api/Program.cs) - Added seeding logic
- ✅ [appsettings.json](virtual-library/api/VirtualLibrary.Api/appsettings.json) - SeedMockData: true
- ✅ [InMemorySeeder.cs](virtual-library/api/VirtualLibrary.Api/Infrastructure/Persistence/InMemorySeeder.cs) - New seeder
- ✅ [CosmosDbSeeder.cs](virtual-library/api/VirtualLibrary.Api/Infrastructure/Persistence/CosmosDbSeeder.cs) - Already exists

---

## Build Status

✅ **0 Errors** | ⚠️ **1 Warning** (Newtonsoft.Json) | ✅ **Ready to Deploy**

---

## Next: See Full Guides

- [COSMOSDB_SEEDING_COMPLETE.md](COSMOSDB_SEEDING_COMPLETE.md) - Complete setup guide
- [INMEMORY_SEEDING_COMPLETE.md](INMEMORY_SEEDING_COMPLETE.md) - In-memory details
- [COSMOSDB_SEEDING_GUIDE.md](COSMOSDB_SEEDING_GUIDE.md) - Production deployment
