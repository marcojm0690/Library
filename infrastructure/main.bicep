param location string = resourceGroup().location
param environment string = 'prod'

@minLength(3)
@maxLength(20)
@description('Application name used for resource naming')
param appName string = 'virtual-library'

// Resource naming
var acrName = '${replace(appName, '-', '')}acr'
var cosmosAccountName = '${appName}-server'
var appServicePlanName = '${appName}-asp-${environment}'
var webAppName = '${appName}-api-web'
var vnetName = '${appName}-vnet'
var cosmosDbName = 'LibraryDb'
var cosmosDbCollection = 'Books'
var redisName = '${appName}-redis-${environment}'

// Create Virtual Network for private endpoints
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'app-service'
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
    ]
  }
}

// Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// Create Cosmos DB Account (MongoDB API)
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: location
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    apiProperties: {
      serverVersion: '4.0'
    }
    enableFreeTier: false
    publicNetworkAccess: 'Enabled'
  }
}

// Create Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: cosmosDbName
  properties: {
    resource: {
      id: cosmosDbName
    }
  }
}

// Create Cosmos DB Collection
resource cosmosCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-04-15' = {
  parent: cosmosDatabase
  name: cosmosDbCollection
  properties: {
    resource: {
      id: cosmosDbCollection
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              'Isbn'
            ]
          }
        }
      ]
    }
    options: {
      throughput: 400
    }
  }
}

// Create Azure Cache for Redis (using latest API version)
resource redis 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableAccessKeyAuthentication: false
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
      'maxmemory-reserved': '30'
    }
    redisVersion: 'latest'
  }
}

// Create App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'Linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

// Create Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/virtual-library-api:latest'
      alwaysOn: false
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      numberOfWorkers: 1
      defaultDocuments: []
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'Azure__MongoDB__ConnectionString'
          value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'Azure__MongoDB__DatabaseName'
          value: cosmosDbName
        }
        {
          name: 'Azure__MongoDB__CollectionName'
          value: cosmosDbCollection
        }
        {
          name: 'Azure__CosmosDb__Endpoint'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'Azure__Redis__ConnectionString'
          value: '${redis.properties.hostName}:6380,password=${redis.listKeys().primaryKey},ssl=True,abortConnect=False'
        }
        {
          name: 'Azure__Redis__CacheExpirationMinutes'
          value: '1440'
        }
      ]
      connectionStrings: [
        {
          name: 'CosmosDb'
          connectionString: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
          type: 'Custom'
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
  }
  dependsOn: [
    cosmosCollection
  ]
}

// Configure container settings for web app
resource webAppContainerSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp
  name: 'web'
  properties: {
    acrUseManagedIdentityCreds: true
    numberOfWorkers: 1
    defaultDocuments: []
  }
}



// Outputs
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output cosmosDbEndpoint string = cosmosAccount.properties.documentEndpoint
output webAppName string = webApp.name
output webAppPrincipalId string = webApp.identity.principalId
output redisHostName string = redis.properties.hostName
output redisName string = redis.name
