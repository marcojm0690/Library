# Azure Integration Guide

## Overview
El API de Virtual Library ahora utiliza Azure para:
1. **Azure Computer Vision** - Identificar libros desde imágenes de portada
2. **Azure Blob Storage** - Almacenar las librerías de usuarios

## Configuración de Azure

### 1. Crear una Cuenta de Azure Storage

```bash
# Crear un grupo de recursos (si no existe)
az group create --name VirtualLibraryRG --location eastus

# Crear una cuenta de almacenamiento
az storage account create \
  --name virtuallibrarystorage \
  --resource-group VirtualLibraryRG \
  --location eastus \
  --sku Standard_LRS

# Obtener la cadena de conexión
az storage account show-connection-string \
  --name virtuallibrarystorage \
  --resource-group VirtualLibraryRG
```

### 2. Crear un Contenedor en Blob Storage

```bash
az storage container create \
  --name user-libraries \
  --account-name virtuallibrarystorage
```

### 3. Configurar Azure Computer Vision

```bash
# Crear un recurso de Computer Vision
az cognitiveservices account create \
  --name VirtualLibraryVision \
  --resource-group VirtualLibraryRG \
  --kind ComputerVision \
  --sku S1 \
  --location eastus \
  --yes

# Obtener las claves
az cognitiveservices account keys list \
  --name VirtualLibraryVision \
  --resource-group VirtualLibraryRG
```

## Actualizar appsettings

Actualiza el archivo `appsettings.json` con tus credenciales de Azure:

```json
{
  "Azure": {
    "Storage": {
      "ConnectionString": "DefaultEndpointsProtocol=https;AccountName=virtuallibrarystorage;AccountKey=YOUR_KEY;EndpointSuffix=core.windows.net",
      "ContainerName": "user-libraries"
    },
    "Vision": {
      "Endpoint": "https://eastus.api.cognitive.microsoft.com/",
      "ApiKey": "YOUR_VISION_API_KEY"
    }
  }
}
```

## Nuevos Endpoints de API

### Identificar un libro desde imagen
```http
POST /api/books/identify-from-image
Content-Type: application/json

{
  "imageData": "base64_encoded_image_here",
  "imageFormat": "jpg"
}
```

### Guardar libro a la librería del usuario
```http
POST /api/books/library/{userId}
Content-Type: application/json

{
  "title": "The Great Gatsby",
  "authors": ["F. Scott Fitzgerald"],
  "publisher": "Scribner",
  "publishYear": 1925,
  "description": "A classic novel"
}
```

### Obtener librería del usuario
```http
GET /api/books/library/{userId}
```

## Estructura de almacenamiento en Blob

```
user-libraries/
├── users/
│   ├── user123/
│   │   ├── library.json
│   │   └── covers/
│   │       ├── book-id-1.jpg
│   │       └── book-id-2.jpg
│   └── user456/
│       ├── library.json
│       └── covers/
```

## Notas de Desarrollo

- **Azure Vision** analiza la portada del libro y extrae información usando OCR y detección de objetos
- **Blob Storage** almacena las librerías de usuarios de forma segura con estructura escalable
- Utiliza `AzureVisionProvider` para análisis de imágenes
- Utiliza `AzureBlobLibraryRepository` para gestionar almacenamiento de librerías

## Precios (Estimados)

- **Azure Blob Storage**: ~$0.021 por GB (primeros 50TB)
- **Computer Vision**: ~$1-7 por 1000 llamadas según el tier
- **Almacenamiento de transacciones**: $0.004 por 10,000 escrituras

Para más información, consulta:
- https://azure.microsoft.com/en-us/pricing/details/storage/blobs/
- https://azure.microsoft.com/en-us/pricing/details/cognitive-services/computer-vision/
