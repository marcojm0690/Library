# Virtual Library - Cosmos DB Seeding Complete Setup

## 🎯 What You Have Now

Your Virtual Library API is **fully configured for automatic Cosmos DB seeding**. Here's what's in place:

### ✅ Completed
- **Dual Seeding System**: In-memory for development, Cosmos DB for production
- **10 Mock Books**: Pre-loaded and ready to seed
- **Auto-Seeding Logic**: Checks if container empty, seeds if needed
- **Idempotent Design**: Safe to run multiple times
- **Environment-Aware**: Uses correct repo based on configuration
- **Managed Identity**: Secure Azure authentication ready

### 📦 What Gets Seeded
```
Programming
├─ The C# Player's Guide (RB Whitaker, 2019)
├─ Clean Code (Robert C. Martin, 2008)
├─ Code Complete (Steve McConnell, 2004)
└─ The Pragmatic Programmer (Hunt & Thomas, 2000)

Fiction
├─ To Kill a Mockingbird (Harper Lee, 1960)
└─ 1984 (George Orwell, 1949)

Science
├─ A Brief History of Time (Stephen Hawking, 1988)
└─ Cosmos (Carl Sagan, 1980)

Business
├─ Good to Great (Jim Collins, 2001)
└─ The Lean Startup (Eric Ries, 2011)
```

## 🚀 How to Use

### Option 1: Development (In-Memory, Works Now ✅)
```bash
cd virtual-library/api/VirtualLibrary.Api
dotnet run

# In another terminal:
curl http://localhost:5000/api/books
# Returns 10 seeded books
```

**Current Status**: ✅ Ready to test - all 10 mock books auto-seed!

### Option 2: Production (Cosmos DB in Azure)

#### Step 1: Create Cosmos DB Account
Currently, the Azure CLI has API issues. **Create manually via Azure Portal:**

1. Go to https://portal.azure.com
2. Search for "Azure Cosmos DB" → Click "Create"
3. Configure:
   - **Account Name**: `virtuallibrary-server`
   - **Resource Group**: `VirtualLibraryRG`
   - **Location**: `Canada Central`
   - **API**: Core (SQL)
   - **Capacity Mode**: Provisioned (400 RU/s)
4. Click "Create" (wait 10-15 minutes)

#### Step 2: Initialize Database & Container
Option A (via Portal - Easiest):
- Open Cosmos DB Account → Data Explorer
- Create Database: `LibraryDb`
- Create Container: `Books` (Partition Key: `/id`)

Option B (via Script):
```bash
# After account is created, run the setup script:
bash setup-cosmosdb.sh
```

#### Step 3: Configure & Deploy
Update `appsettings.json`:
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

Deploy to Azure (App Service):
```bash
dotnet publish -c Release -o ./publish
# Then deploy via Azure Portal or CLI
```

#### Step 4: Verify Seeding
After app starts, check Cosmos DB:
- Azure Portal → Cosmos DB → Data Explorer → Select `Books` container
- Should see 10 items

## 📁 Project Files Added/Modified

### New Files Created
| File | Purpose |
|------|---------|
| [InMemorySeeder.cs](virtual-library/api/VirtualLibrary.Api/Infrastructure/Persistence/InMemorySeeder.cs) | Seeds in-memory repo with 10 books |
| [INMEMORY_SEEDING_COMPLETE.md](INMEMORY_SEEDING_COMPLETE.md) | In-memory setup documentation |
| [COSMOSDB_SEEDING_GUIDE.md](COSMOSDB_SEEDING_GUIDE.md) | Production seeding guide |
| [setup-cosmosdb.sh](setup-cosmosdb.sh) | One-command setup script |

### Modified Files
| File | Change |
|------|--------|
| [Program.cs](virtual-library/api/VirtualLibrary.Api/Program.cs) | Added seeding logic for both repositories |
| [appsettings.json](virtual-library/api/VirtualLibrary.Api/appsettings.json) | Set SeedMockData to true for automatic seeding |
| [appsettings.Development.json](virtual-library/api/VirtualLibrary.Api/appsettings.Development.json) | Cosmos DB endpoint set to empty (triggers in-memory) |

## 🔄 How Seeding Works

### Development Path (Currently Active)
```
App starts in Development environment
    ↓
Checks appsettings.Development.json
    ↓
Sees Endpoint = "" (empty)
    ↓
Registers InMemoryBookRepository
    ↓
Calls InMemorySeeder.SeedMockBooksAsync()
    ↓
✅ 10 books loaded in memory
    ↓
API ready to query
```

### Production Path (When Cosmos DB is Ready)
```
App starts with Cosmos DB endpoint configured
    ↓
Registers CosmosDbBookRepository
    ↓
Connects to Azure Cosmos DB
    ↓
Calls CosmosDbSeeder.SeedIfEmptyAsync()
    ↓
Checks if Books container is empty
    ↓
If empty: Seeds 10 books ✅
If not empty: Skips (idempotent)
    ↓
API queries from Cosmos DB
```

## 🧪 Testing Checklist

### Local Testing (Development)
- [ ] Run `dotnet run`
- [ ] Check console for startup logs
- [ ] `curl http://localhost:5000/api/books` returns 10 books
- [ ] `curl "http://localhost:5000/api/books/isbn/978-0-13-235088-4"` returns "Clean Code"
- [ ] `curl "http://localhost:5000/api/books/search?query=Orwell"` returns "1984"

### Cloud Testing (When Cosmos DB Ready)
- [ ] Cosmos DB account created in Azure Portal
- [ ] Database `LibraryDb` exists
- [ ] Container `Books` exists
- [ ] appsettings.json updated with real endpoint
- [ ] App deployed to Azure App Service
- [ ] Check Cosmos DB Data Explorer → 10 items visible
- [ ] API queries return seeded books
- [ ] Restart app → no duplicate seeding (idempotent)

## 💾 Configuration Reference

### appsettings.Development.json (Local)
```json
"Azure": {
  "CosmosDb": {
    "Endpoint": "",  // Empty = use in-memory with auto-seeding
    "DatabaseName": "LibraryDb",
    "ContainerName": "Books",
    "SeedMockData": false  // Not used with empty endpoint
  }
}
```

### appsettings.json (Production)
```json
"Azure": {
  "CosmosDb": {
    "Endpoint": "https://virtuallibrary-server.documents.azure.com:443/",
    "DatabaseName": "LibraryDb",
    "ContainerName": "Books",
    "SeedMockData": true  // Auto-seed on first startup
  }
}
```

## 🔐 Security Setup for Cosmos DB

When deploying to Azure, use Managed Identity:

1. **Enable Managed Identity** on App Service:
   ```bash
   az webapp identity assign -g VirtualLibraryRG -n virtuallibrary-api
   ```

2. **Assign Cosmos DB Role**:
   ```bash
   # Get the principal ID
   PRINCIPAL_ID=$(az webapp identity show -g VirtualLibraryRG -n virtuallibrary-api \
     --query principalId -o tsv)
   
   # Assign role
   az cosmosdb sql role assignment create \
     -a virtuallibrary-server \
     -r "00000000-0000-0000-0000-000000000002" \
     -p "$PRINCIPAL_ID" \
     -g VirtualLibraryRG
   ```

3. **No Connection Strings Needed** - App uses Managed Identity automatically

## 📊 Current Build Status

```
✅ Build: Succeeded
✅ Errors: 0
⚠️  Warnings: 1 (Newtonsoft.Json - not critical)
✅ In-Memory Seeding: Ready to test
⏳ Cosmos DB: Awaiting manual account creation in Azure Portal
```

## 📝 Next Steps (Ordered by Priority)

1. **Test In-Memory (5 minutes)** ✅ Ready Now
   ```bash
   cd virtual-library/api/VirtualLibrary.Api && dotnet run
   curl http://localhost:5000/api/books
   ```

2. **Create Cosmos DB (10-15 minutes)**
   - Go to Azure Portal
   - Create `virtuallibrary-server` account
   - Create `LibraryDb` database
   - Create `Books` container

3. **Update Configuration (2 minutes)**
   - Get endpoint: `az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG --query documentEndpoint -o tsv`
   - Update appsettings.json with endpoint
   - Verify SeedMockData = true

4. **Deploy to Azure (5-10 minutes)**
   - Build: `dotnet publish -c Release`
   - Deploy to App Service
   - Monitor logs: `az webapp log tail -g VirtualLibraryRG -n virtuallibrary-api`

5. **Verify Seeding (2 minutes)**
   - Azure Portal → Cosmos DB → Data Explorer
   - Check `Books` container has 10 items
   - Test API endpoints

## 🎓 Architecture Diagram

```
┌─────────────────────────────────────────┐
│      Virtual Library API (ASP.NET)      │
└──────────────┬──────────────────────────┘
               │
        Startup Configuration
               │
        ┌──────┴────────┐
        │               │
   Check Endpoint    Check Endpoint
   in Settings       in Settings
        │               │
    Empty String    Has Value
        │               │
        ▼               ▼
┌──────────────┐  ┌─────────────────┐
│   In-Memory  │  │  Cosmos DB      │
│  Repository  │  │  Repository     │
│              │  │  (Azure)        │
├──────────────┤  └────────┬────────┘
│  Development │           │
│  (Localhost) │    Seeding Logic
│              │           │
│  Auto-Seeds  │      ┌────▼──────┐
│  10 Books    │      │ Is Empty? │
│              │      └────┬─────┬┘
│  No Persist  │           │     │
│  (Memory)    │         Yes    No
└──────────────┘           │     │
                           ▼     ▼
                      Seed    Skip
                      10      (Safe)
                    Books
```

## 🆘 Troubleshooting

**In-Memory (Development)**
- No books returned? → Ensure `Endpoint: ""` in appsettings.Development.json
- Build fails? → Check VirtualLibrary.Api.csproj for missing NuGet packages
- App doesn't start? → Run `dotnet restore` then `dotnet build`

**Cosmos DB (Production)**
- Account creation fails? → Check Azure quota, try Azure Portal instead of CLI
- Seeding not running? → Check app logs, verify SeedMockData=true
- Books not showing? → Check Data Explorer, verify container exists
- API 404 errors? → Verify Cosmos DB has items via Data Explorer

**Build Issues**
```bash
# Clean build
rm -rf bin obj
dotnet clean
dotnet build --no-cache

# Restore packages
dotnet restore

# Check for errors
dotnet build --no-restore 2>&1 | grep -i error
```

## 📚 Additional Documentation

- [INMEMORY_SEEDING_COMPLETE.md](INMEMORY_SEEDING_COMPLETE.md) - In-memory setup details
- [COSMOSDB_SEEDING_GUIDE.md](COSMOSDB_SEEDING_GUIDE.md) - Production seeding guide
- [COSMOS_DB_COMPLETE_SUMMARY.md](COSMOS_DB_COMPLETE_SUMMARY.md) - Technical deep dive
- [setup-cosmosdb.sh](setup-cosmosdb.sh) - Automated setup script

## ✨ Summary

Your Virtual Library API now has **production-ready seeding** configured. You can:

1. ✅ **Test immediately** with in-memory repository (10 mock books auto-loaded)
2. ✅ **Deploy to Azure** with automatic Cosmos DB seeding when account is ready
3. ✅ **Scale reliably** with idempotent seeding (safe to restart anytime)
4. ✅ **Maintain easily** with separate seeders for each environment

**Ready to go!** Start with `dotnet run` to test locally. 🚀
