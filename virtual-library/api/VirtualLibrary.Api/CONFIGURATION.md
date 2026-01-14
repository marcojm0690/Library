# Configuration Guide

## Local Development Setup

The MongoDB connection string is stored securely using .NET User Secrets (not committed to git).

### Set up user secrets:

```bash
cd virtual-library/api/VirtualLibrary.Api

# Initialize user secrets (already done)
dotnet user-secrets init

# Set your MongoDB connection string
dotnet user-secrets set "Azure:MongoDB:ConnectionString" "mongodb://virtuallibrary-server:YOUR_KEY@virtuallibrary-server.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@virtuallibrary-server@"
```

### Get your connection string:

```bash
az cosmosdb keys list -n virtuallibrary-server -g biblioteca --type connection-strings --query "connectionStrings[0].connectionString" -o tsv
```

## Production Deployment (Azure App Service)

Set as environment variable or app setting:

```bash
az webapp config appsettings set \
  --resource-group biblioteca \
  --name YOUR_APP_NAME \
  --settings Azure__MongoDB__ConnectionString="YOUR_CONNECTION_STRING"
```

## Configuration Hierarchy

1. User Secrets (development only - highest priority)
2. Environment Variables
3. appsettings.Development.json
4. appsettings.json (never contains secrets)

## Security Notes

- ✅ User secrets are stored locally at: `~/.microsoft/usersecrets/<user-secrets-id>/secrets.json`
- ✅ Never commit connection strings to source control
- ✅ Use environment variables in production
- ✅ GitHub push protection will block secrets in commits
