# Quick Start - Cosmos DB Deployment

## 1️⃣ Check Cosmos DB Account Status
```bash
# Wait ~10 minutes, then check:
az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG \
  --query '{name:.name, endpoint:.documentEndpoint, state:.properties.provisioningState}' -o table
```

Expected: `state = Succeeded`

---

## 2️⃣ Initialize Database & Container (Once Account Ready)
```bash
COSMOS_ACCOUNT_NAME=virtuallibrary-server \
COSMOS_RESOURCE_GROUP=VirtualLibraryRG \
COSMOS_DATABASE_NAME=LibraryDb \
COSMOS_CONTAINER_NAME=Books \
./scripts/initialize-cosmosdb.sh
```

---

## 3️⃣ Get Configuration Values
```bash
COSMOS_ENDPOINT=$(az cosmosdb show -n virtuallibrary-server -g VirtualLibraryRG \
  --query documentEndpoint -o tsv)

cat << EOF
COSMOS_ACCOUNT_NAME=virtuallibrary-server
COSMOS_ENDPOINT=$COSMOS_ENDPOINT
COSMOS_DB_NAME=LibraryDb
COSMOS_CONTAINER_NAME=Books
EOF
```

---

## 4️⃣ Build & Push Docker Image

**Option A: GitHub Actions (Recommended)**
```bash
git add .
git commit -m "Add Cosmos DB integration"
git push origin main
# Wait for workflow to complete
```

**Option B: Manual**
```bash
docker build -t virtual-library-api:latest .
docker tag virtual-library-api:latest virtuallibraryacr.azurecr.io/virtual-library-api:latest
az acr login --name virtuallibraryacr
docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest
```

---

## 5️⃣ Deploy to Web App
```bash
./scripts/deploy-webapp.sh
```

**Environment variables needed:**
```bash
export RG=VirtualLibraryRG
export LOCATION=canadacentral
export PLAN_NAME=vl-asp-linux
export WEBAPP_NAME=virtual-library-api-web
export ACR_NAME=virtuallibraryacr
export ACR_LOGIN_SERVER=virtuallibraryacr.azurecr.io
export IMAGE_NAME=virtual-library-api
export IMAGE_TAG=latest
export STORAGE_ACCOUNT_NAME=vllibrarystorage9496
export STORAGE_CONTAINER_NAME=user-libraries
export COSMOS_ACCOUNT_NAME=virtuallibrary-server
export COSMOS_ENDPOINT=https://virtuallibrary-server.documents.azure.com:443/
export COSMOS_DB_NAME=LibraryDb
export COSMOS_CONTAINER_NAME=Books
export VISION_ENDPOINT=https://canadacentral.api.cognitive.microsoft.com/

./scripts/deploy-webapp.sh
```

---

## 6️⃣ Verify Deployment
```bash
# Check Swagger UI
curl https://virtual-library-api-web.azurewebsites.net/swagger/

# Check logs
az webapp log tail -g VirtualLibraryRG -n virtual-library-api-web
```

---

## ✅ Success Indicators

**Cosmos DB**:
- ✓ Account exists in Azure Portal
- ✓ Database `LibraryDb` visible
- ✓ Container `Books` visible with 400 RUs

**App Service**:
- ✓ Container running (check Deployment Center)
- ✓ App settings include Cosmos DB config
- ✓ Managed Identity has "Cosmos DB Built-in Data Contributor" role

**API**:
- ✓ Swagger UI loads: https://virtual-library-api-web.azurewebsites.net/swagger/
- ✓ No errors in Application Insights logs
- ✓ POST /api/books works (saves to Cosmos DB)
- ✓ GET /api/books works (queries Cosmos DB)

---

## 🐛 If Something Goes Wrong

### Cosmos DB Account Still Creating
→ Wait 15 minutes, check status with command in Step 1

### "Cosmos DB Built-in Data Contributor" Role Missing
→ Run manually:
```bash
PRINCIPAL_ID=$(az webapp identity show -g VirtualLibraryRG \
  -n virtual-library-api-web --query principalId -o tsv)
  
COSMOS_ID=$(az cosmosdb show -n virtuallibrary-server \
  -g VirtualLibraryRG --query id -o tsv)

az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Cosmos DB Built-in Data Contributor" \
  --scope "$COSMOS_ID"
```

### App Crashes on Startup
→ Check logs:
```bash
az webapp log tail -g VirtualLibraryRG -n virtual-library-api-web
```
→ If "Failed to initialize Cosmos DB" - that's OK, app falls back to in-memory

### Swagger Doesn't Load
→ Make sure app fully started (wait 30 seconds), then retry

---

## 📚 Full Documentation
See **COSMOS_DB_COMPLETE_SUMMARY.md** for detailed architecture, troubleshooting, and design decisions.
