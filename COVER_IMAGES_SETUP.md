# Enhanced Cover Image Sources

Added **ISBNdb** and **Wikidata** for better cover image coverage!

## 🎯 Priority Order

When enriching books, the API tries providers in this order:

1. **ISBNdb** - Best cover images, comprehensive data (requires API key)
2. **Wikidata** - Free, high-quality images from Wikimedia Commons
3. **Google Books** - Good fallback
4. **Open Library** - Last resort

## 🔑 ISBNdb Setup (Optional but Recommended)

### Get Free API Key:
1. Go to https://isbndb.com/isbn-database
2. Sign up for free account
3. Get your API key (1000 requests/day free)

### Add to Configuration:

**Local Development** (`appsettings.local.json`):
```json
{
  "ISBNdb": {
    "ApiKey": "YOUR_API_KEY_HERE"
  }
}
```

**Azure Deployment**:
```bash
az webapp config appsettings set \
  --resource-group biblioteca \
  --name virtual-library-api-web \
  --settings ISBNdb__ApiKey="YOUR_API_KEY_HERE"
```

## 🆓 Wikidata (No Setup Required)

- Completely free, no API key needed
- Uses SPARQL queries to fetch book data
- Gets high-quality cover images from Wikimedia Commons
- Good for classic/academic books

## 📊 What Changed

### New Providers:
- ✅ `ISBNdbBookProvider` - Cover images + metadata
- ✅ `WikidataBookProvider` - Free cover images from Wikimedia

### Enhanced Enrichment:
- Prioritizes getting cover images first
- Tries all providers until a cover is found
- Updates books in database automatically
- Logs which provider supplied the cover

### Example Flow:
```
1. Book scanned: "Kritik der reinen Vernunft"
2. No cover in database
3. Try ISBNdb → ✅ Found cover!
4. Save cover URL to database
5. Display book with cover immediately
```

## 🚀 Deploy

Build and publish:
```bash
cd virtual-library/api/VirtualLibrary.Api
dotnet build
dotnet publish -c Release -o publish
```

Deploy to Azure:
```bash
cd publish
zip -r ../publish.zip .
cd ..
az webapp deploy \
  --resource-group biblioteca \
  --name virtual-library-api-web \
  --src-path publish.zip \
  --type zip
```

## 📈 Expected Coverage

- **With ISBNdb**: ~85% cover images
- **Without ISBNdb**: ~60% cover images (Wikidata + Google + OpenLibrary)

## 🔍 Testing

Scan these books to test cover sources:
- "Kritik der reinen Vernunft" (Wikidata)
- "The Great Gatsby" (ISBNdb/Google)
- "Don Quixote" (All sources)

Check logs to see which provider returned the cover!
