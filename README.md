# 📚 Virtual Library

A cloud-native mono-repository containing a .NET 8 Web API and iOS SwiftUI app for identifying and cataloging books through ISBN barcode scanning and cover image analysis (OCR).

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![Swift](https://img.shields.io/badge/Swift-6.2.3-FA7343?logo=swift)](https://swift.org/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoftazure)](https://azure.microsoft.com/)
[![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?logo=docker)](https://www.docker.com/)

## 🎯 Overview

Virtual Library provides a seamless way to identify and catalog books using modern mobile technology. Point your camera at a book's barcode or cover, and instantly retrieve comprehensive book information including title, author, publisher, description, and cover images.

### Key Features

- 📱 **ISBN Barcode Scanning** - Instant book lookup via camera barcode detection
- 🖼️ **Cover Image OCR** - Identify books by photographing the cover
- 🌍 **Multi-Provider Search** - Queries Google Books, Open Library, and ISBNdb
- 🔄 **Smart Caching** - Redis-based caching for improved performance
- ☁️ **Azure-Powered** - Scalable cloud infrastructure with Cosmos DB
- 🎨 **Modern UI** - Native iOS app built with SwiftUI
- 🔒 **Secure** - Managed Identity authentication, no hardcoded credentials
- 🐳 **Containerized** - Docker-based deployment with Azure Container Registry

## 📁 Repository Structure

```
Library/
├── README.md                           # This file
├── Dockerfile                          # Container build configuration
├── Library.sln                         # .NET solution file
│
├── virtual-library/                    # Application code
│   ├── api/                            # .NET 8 Web API
│   │   └── VirtualLibrary.Api/
│   │       ├── Controllers/            # REST API endpoints
│   │       ├── Application/            # Business logic & services
│   │       ├── Domain/                 # Core entities
│   │       └── Infrastructure/         # Azure integrations & data access
│   │
│   ├── ios/                            # iOS SwiftUI App
│   │   └── VirtualLibraryApp/
│   │       ├── Views/                  # SwiftUI views
│   │       ├── ViewModels/             # MVVM pattern
│   │       ├── Services/               # Camera, OCR, API clients
│   │       └── Models/                 # Data models
│   │
│   ├── shared/contracts/               # API contract documentation
│   └── docs/                           # Additional documentation
│
├── infrastructure/                     # Azure Infrastructure as Code
│   ├── main.bicep                      # Bicep template
│   ├── parameters.json                 # Deployment parameters
│   ├── deploy.sh                       # Deployment script
│   └── README.md                       # Infrastructure docs
│
├── scripts/                            # Automation scripts
│   ├── deploy-webapp.sh                # Web app deployment
│   ├── provision-azure-resources.sh    # Resource provisioning
│   └── initialize-cosmosdb.sh          # Database initialization
│
└── deployments/                        # Deployment history tracking
```

## 🏗️ Architecture

### Technology Stack

**Backend**
- .NET 8 with Minimal APIs
- Clean Architecture pattern
- Azure Cosmos DB (NoSQL)
- Azure Redis Cache
- Azure Computer Vision (OCR)
- Docker containerization

**Frontend**
- SwiftUI (iOS 16+)
- MVVM architecture
- AVFoundation (barcode scanning)
- Vision framework (OCR)
- Async/await networking

**Infrastructure**
- Azure App Service (Linux containers)
- Azure Container Registry
- Azure Cosmos DB (MongoDB API)
- Azure Virtual Network
- Bicep/ARM templates
- Managed Identity authentication

### API Endpoints

```
POST /api/books/lookup              # Look up book by ISBN
POST /api/books/search-by-cover     # Search books by OCR text
GET  /api/libraries                 # List user libraries
POST /api/quotes                    # Add book quotes
```

## 🚀 Getting Started

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Docker](https://www.docker.com/get-started) (for containerization)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (for deployment)
- [Xcode 15+](https://developer.apple.com/xcode/) (for iOS development)
- Azure subscription (for cloud deployment)

### Local Development

#### Running the API Locally

```bash
# Navigate to API project
cd virtual-library/api/VirtualLibrary.Api

# Restore dependencies
dotnet restore

# Run the application
dotnet run

# Access Swagger UI
open http://localhost:5000/swagger
```

#### Running with Docker

```bash
# Build the Docker image
docker build -t virtual-library-api:latest -f Dockerfile .

# Run the container
docker run -p 5000:8080 \
  -e Azure__MongoDB__ConnectionString="your-connection-string" \
  virtual-library-api:latest
```

#### Running the iOS App

1. Open `virtual-library/ios/VirtualLibrary.xcworkspace` in Xcode
2. Update API endpoint in `Services/BookApiService.swift`
3. Build and run on simulator or device
4. **Note:** Camera features require a physical iOS device

### Configuration

Create `appsettings.local.json` (see `appsettings.local.json.example`):

```json
{
  "Azure": {
    "MongoDB": {
      "ConnectionString": "your-cosmos-connection-string",
      "DatabaseName": "LibraryDb"
    },
    "Redis": {
      "ConnectionString": "your-redis-connection-string"
    }
  }
}
```

## ☁️ Azure Deployment

### Quick Deploy

```bash
# 1. Provision Azure infrastructure
./infrastructure/deploy.sh

# 2. Build and push Docker image
docker build -t virtuallibraryacr.azurecr.io/virtual-library-api:latest .
az acr login --name virtuallibraryacr
docker push virtuallibraryacr.azurecr.io/virtual-library-api:latest

# 3. Deploy to Azure Web App
./scripts/deploy-webapp.sh
```

### Infrastructure Resources

The deployment creates:
- Azure Container Registry (ACR)
- App Service Plan (Linux B1)
- App Service with Docker container
- Azure Cosmos DB (MongoDB API)
- Virtual Network
- Managed Identity with RBAC
- Redis Cache (optional)

See [infrastructure/README.md](infrastructure/README.md) for detailed deployment documentation.

## 📖 Documentation

- [Virtual Library App Documentation](virtual-library/README.md) - Complete app documentation
- [Architecture Documentation](virtual-library/docs/architecture.md) - Detailed architecture guide
- [API Contracts](virtual-library/shared/contracts/book-contracts.md) - API specifications
- [Infrastructure Guide](infrastructure/README.md) - Azure deployment guide

## 🔐 Security

- ✅ Managed Identity for Azure resource authentication
- ✅ ACR integration with RBAC (AcrPull role)
- ✅ Cosmos DB access via Managed Identity
- ✅ No hardcoded credentials in code
- ✅ HTTPS/TLS encryption
- ✅ Virtual Network integration available

## 🛠️ Development

### Project Commands

```bash
# Build solution
dotnet build Library.sln

# Run tests
dotnet test

# Format code
dotnet format

# Publish API
dotnet publish virtual-library/api/VirtualLibrary.Api -c Release -o publish
```

### Scripts

- `scripts/deploy-webapp.sh` - Deploy web app to Azure
- `scripts/provision-azure-resources.sh` - Provision infrastructure
- `scripts/initialize-cosmosdb.sh` - Initialize Cosmos DB
- `infrastructure/deploy.sh` - Deploy Bicep templates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is private and proprietary.

## 🔗 Related Resources

- [.NET 10 Documentation](https://docs.microsoft.com/dotnet/)
- [Azure App Service](https://docs.microsoft.com/azure/app-service/)
- [Azure Cosmos DB](https://docs.microsoft.com/azure/cosmos-db/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Google Books API](https://developers.google.com/books)
- [Open Library API](https://openlibrary.org/developers/api)

---

**Built with ❤️ using .NET, Swift, and Azure**