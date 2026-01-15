# Virtual Library - Deployment Checklist

## ✅ Completed Tasks

### Infrastructure Setup
- [x] Created Bicep infrastructure template (`infrastructure/main.bicep`)
- [x] Created parameters file (`infrastructure/parameters.json`)
- [x] Created deployment script (`infrastructure/deploy.sh`)
- [x] Deployed all Azure resources to `biblioteca` resource group
- [x] Configured Cosmos DB (MongoDB API) with database and collection
- [x] Set up Virtual Network for private endpoints
- [x] Enabled Managed Identity on Web App
- [x] Assigned ACR Pull role to Web App

### Application Configuration
- [x] Updated `appsettings.json` with Cosmos DB connection string
- [x] Configured `Program.cs` to use MongoDB repository
- [x] Set up `MongoDbSeeder` for seeding initial data
- [x] Configured Web App settings (environment, port, connection strings)
- [x] Enabled managed identity credentials for ACR access

### Resource Status
```
Resource Group: biblioteca
ACR: virtuallibraryacr
Web App: virtual-library-api-web
App Plan: virtual-library-asp-prod
Cosmos DB: virtual-library-server
Database: LibraryDb
Collection: Books
```

## 📋 Remaining Tasks (TO-DO)

### 1. Azure DevOps Service Connection
**STATUS:** ⏳ PENDING

**Action Required:**
```
Azure DevOps Project Settings → Service Connections
↓
New Service Connection → Docker Registry
↓
Configuration:
  • Type: Azure Container Registry
  • Subscription: [Select your subscription]
  • Registry: virtuallibraryacr
  • Resource Group: biblioteca
  • Service connection name: virtuallibraryacr
↓
Save
```

### 2. Build & Push Docker Image
**STATUS:** ⏳ PENDING

**Choose one option:**

**Option A: Via Azure Pipelines (Recommended)**
```
1. Ensure service connection is configured (Step 1)
2. Push code to 'main' branch
3. Pipeline will automatically:
   ✓ Build Docker image
   ✓ Push to ACR
   ✓ Deploy to Web App
```

**Option B: Manual Docker Build**
```bash
# Login to ACR
az acr login -n virtuallibraryacr

# Build image
docker build -t virtuallibraryacr.azurecr.io/virtual-library-api:latest .

# Push to ACR
docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest
```

### 3. Verify Deployment
**STATUS:** ⏳ PENDING

```bash
# Check if image exists in ACR
az acr repository show -n virtuallibraryacr --repository virtual-library-api

# Check Web App logs
az webapp log tail -g biblioteca -n virtual-library-api-web

# Verify Cosmos DB data
# Use Azure Portal or MongoDB client to connect to:
# mongodb://virtuallibrary-server:password@virtuallibrary-server.mongo.cosmos.azure.com:10255
```

### 4. Test Application
**STATUS:** ⏳ PENDING

```bash
# Access Swagger UI
https://virtual-library-api-web.azurewebsites.net/swagger/index.html

# Or via curl
curl https://virtual-library-api-web.azurewebsites.net/health
```

## 📊 Resource Deployment Summary

| Resource | Type | Status | Details |
|----------|------|--------|---------|
| ACR | Container Registry | ✅ Created | virtuallibraryacr.azurecr.io |
| Web App | App Service | ✅ Created | virtual-library-api-web |
| App Plan | Service Plan | ✅ Created | virtual-library-asp-prod (B1) |
| Cosmos DB | Database Account | ✅ Created | virtual-library-server |
| LibraryDb | MongoDB Database | ✅ Created | 400 RU/s throughput |
| Books | Collection | ✅ Created | Indexed on Isbn |
| VNet | Virtual Network | ✅ Created | 10.0.0.0/16 |
| Managed ID | System Identity | ✅ Enabled | b577378e-ce25-4ecf-ae35-22f3918ecf3d |
| Docker Image | Container Image | ❌ Pending | Waiting for build |

## 🔐 Security Configuration

### Networking
- [x] Virtual Network configured with private subnets
- [x] Private endpoint infrastructure ready
- [ ] Private endpoints for Cosmos DB (Optional - future)
- [ ] Network Security Groups (Optional - future)

### Identity & Access
- [x] Managed Identity enabled on Web App
- [x] AcrPull role assigned (Web App → ACR)
- [x] Cosmos DB Data Contributor role assigned
- [ ] Azure Key Vault integration (Optional - future)
- [ ] Role-Based Access Control auditing (Optional - future)

### Data
- [x] MongoDB API enabled (no public SQL API)
- [x] Connection string in app settings (not hardcoded)
- [x] Database connection validated

## 📦 Code Status

### Backend (.NET)
```
virtual-library/api/VirtualLibrary.Api/
├── appsettings.json ✅ Updated with MongoDB connection
├── Program.cs ✅ Configured for MongoDB
├── Infrastructure/Persistence/
│   ├── MongoDbBookRepository.cs ✅ Ready
│   └── MongoDbSeeder.cs ✅ Ready to seed data
└── Controllers/
    └── BooksController.cs ✅ Ready
```

### Infrastructure
```
infrastructure/
├── main.bicep ✅ Complete
├── parameters.json ✅ Complete
├── deploy.sh ✅ Complete
└── README.md ✅ Complete
```

### CI/CD
```
azure-pipelines-complete.yml ✅ Created
  • DeployInfrastructure stage
  • Build stage
  • Deploy stage
```

## 🚀 Quick Start Commands

### Deploy Infrastructure
```bash
cd /path/to/Library
./infrastructure/deploy.sh
```

### Build and Push Docker Image
```bash
docker build -t virtuallibraryacr.azurecr.io/virtual-library-api:latest .
az acr login -n virtuallibraryacr
docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest
```

### Check Web App Logs
```bash
az webapp log tail -g biblioteca -n virtual-library-api-web
```

### Restart Web App
```bash
az webapp restart -g biblioteca -n virtual-library-api-web
```

### List All Resources
```bash
az resource list -g biblioteca --query "[].{name:name, type:type}" -o table
```

## 📚 Documentation

- **Infrastructure Guide**: `infrastructure/README.md`
- **Bicep Template**: `infrastructure/main.bicep`
- **API Documentation**: Will be available at `/swagger/index.html` after deployment
- **Azure Resources**: [Azure Portal](https://portal.azure.com)

## 🎯 Success Criteria

- [ ] Service connection configured in Azure DevOps
- [ ] Docker image built and pushed to ACR
- [ ] Web App pulls and runs the Docker image
- [ ] Swagger UI accessible at `https://virtual-library-api-web.azurewebsites.net/swagger/index.html`
- [ ] API endpoints responding (HTTP 200)
- [ ] MongoDbSeeder runs and seeds initial data
- [ ] Database contains 10 books
- [ ] API can query books by ISBN

## 🆘 Troubleshooting

### Web App shows "Application Error"
```bash
# Check logs
az webapp log download -g biblioteca -n virtual-library-api-web --log-file logs.zip
unzip -p logs.zip | tail -100

# Check if image exists
az acr repository list -n virtuallibraryacr
```

### Docker image not found in ACR
```bash
# Push the image
docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest

# Verify it's there
az acr repository show -n virtuallibraryacr --repository virtual-library-api
```

### Cosmos DB connection fails
```bash
# Check connection string is set
az webapp config appsettings list -g biblioteca -n virtual-library-api-web \
  --query "[?name=='Azure__MongoDB__ConnectionString']"

# Verify database exists
az cosmosdb database list -n virtual-library-server -g biblioteca
```

## 📞 Support

For issues or questions:
1. Check logs: `az webapp log tail -g biblioteca -n virtual-library-api-web`
2. Review Bicep template: `infrastructure/main.bicep`
3. Check Infrastructure README: `infrastructure/README.md`
4. Azure Portal: [Link](https://portal.azure.com)

---

**Last Updated:** 2026-01-15
**Infrastructure Version:** 1.0
**Status:** Ready for Docker image deployment
