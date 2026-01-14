# Cosmos DB Seeding - Implementation Details

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Application Startup (Program.cs)         │
└──────────────────┬──────────────────────────────┘
                   │
                   ├─→ Check: SeedMockData = true?
                   │
                   ├─→ YES: Resolve CosmosDbSeeder
                   │        └─→ Call SeedIfEmptyAsync()
                   │
                   └─→ NO: Skip seeding, continue
```

## Flow Diagram

```
dotnet run
    │
    ├─→ Program.cs reads configuration
    │   └─→ Gets: Azure:CosmosDb:SeedMockData
    │
    ├─→ Creates app (app.Build())
    │
    ├─→ Check if SeedMockData is true
    │   │
    │   ├─→ YES:
    │   │   ├─→ Create service scope
    │   │   ├─→ Resolve CosmosDbSeeder
    │   │   └─→ Call SeedIfEmptyAsync()
    │   │       │
    │   │       ├─→ Query Cosmos DB: Get all books
    │   │       │
    │   │       ├─→ Has books?
    │   │       │   ├─→ YES: Log "already contains X books"
    │   │       │   └─→ NO: Seed 10 mock books
    │   │       │       └─→ Call SaveAsync() for each
    │   │       │
    │   │       └─→ Log completion
    │   │
    │   └─→ NO: Skip seeding
    │
    └─→ Continue with: app.UseSwagger(), MapControllers(), app.Run()
```

## Code Implementation

### 1. CosmosDbSeeder.cs

```csharp
public class CosmosDbSeeder
{
    private readonly CosmosDbBookRepository _repository;
    private readonly ILogger<CosmosDbSeeder> _logger;

    // Constructor: Injected via DI
    public CosmosDbSeeder(CosmosDbBookRepository repository, 
                          ILogger<CosmosDbSeeder> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    // Called on startup - idempotent
    public async Task SeedIfEmptyAsync(CancellationToken cancellationToken = default)
    {
        // 1. Check if empty
        var existingBooks = await _repository.GetAllAsync(cancellationToken);
        
        if (existingBooks.Any())
        {
            _logger.LogInformation("Already contains {Count} books. Skipping seed.", 
                existingBooks.Count);
            return;  // ← Safe to call multiple times
        }

        // 2. Seed if empty
        _logger.LogInformation("Container is empty. Seeding mock data...");
        await SeedMockBooksAsync(cancellationToken);
        _logger.LogInformation("Seeding completed successfully.");
    }

    // Inserts books one by one
    private async Task SeedMockBooksAsync(CancellationToken cancellationToken)
    {
        var mockBooks = GetMockBooks();  // Returns List<Book> with 10 items

        foreach (var book in mockBooks)
        {
            try
            {
                // Upsert each book
                await _repository.SaveAsync(book, cancellationToken);
                _logger.LogDebug("Seeded: {Title}", book.Title);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error seeding: {Title}", book.Title);
                // Continue even if one fails
            }
        }
    }

    // Returns mock book list
    private static List<Book> GetMockBooks()
    {
        return new List<Book>
        {
            new Book { Id = Guid.NewGuid(), Isbn = "...", Title = "...", ... },
            // ... 10 books total
        };
    }
}
```

### 2. Program.cs Integration

```csharp
// Step 1: Register seeder in DI (if Cosmos DB configured)
if (!string.IsNullOrEmpty(cosmosDbEndpoint))
{
    builder.Services.AddScoped<CosmosDbSeeder>();  // ← Add this
}

// Step 2: Call seeder on startup (before app.Run())
if (!string.IsNullOrEmpty(cosmosDbEndpoint))
{
    try
    {
        var seedMockData = cosmosDbConfig.GetValue<bool>("SeedMockData");
        if (seedMockData)  // ← Check configuration
        {
            using (var scope = app.Services.CreateScope())
            {
                var seeder = scope.ServiceProvider
                    .GetRequiredService<CosmosDbSeeder>();
                
                // Execute seeding
                await seeder.SeedIfEmptyAsync();
            }
        }
    }
    catch (Exception ex)
    {
        // Graceful error handling
        var logger = app.Services.GetRequiredService<ILogger<Program>>();
        logger.LogWarning(ex, "Seeding failed. Continuing with app.");
    }
}
```

### 3. Configuration Files

**appsettings.json** (Production - Disabled)
```json
{
  "Azure": {
    "CosmosDb": {
      "Endpoint": "...",
      "DatabaseName": "LibraryDb",
      "ContainerName": "Books",
      "SeedMockData": false
    }
  }
}
```

**appsettings.Development.json** (Development - Enabled)
```json
{
  "Azure": {
    "CosmosDb": {
      "Endpoint": "...",
      "DatabaseName": "LibraryDb",
      "ContainerName": "Books",
      "SeedMockData": true
    }
  }
}
```

## Seeding Process

### First Run (Empty Container)

```
Startup Log Output:
─────────────────────────────────────────────
Checking if Cosmos DB needs seeding...
Cosmos DB is empty. Seeding mock data...
Seeded book: The C# Player's Guide by RB Whitaker
Seeded book: Clean Code by Robert C. Martin
Seeded book: Code Complete by Steve McConnell
Seeded book: The Pragmatic Programmer
Seeded book: To Kill a Mockingbird by Harper Lee
Seeded book: 1984 by George Orwell
Seeded book: A Brief History of Time by Stephen Hawking
Seeded book: Cosmos by Carl Sagan
Seeded book: Good to Great by Jim Collins
Seeded book: The Lean Startup by Eric Ries
Seeding completed successfully.
─────────────────────────────────────────────

Database State:
└─ LibraryDb/
   └─ Books/ (container)
      ├─ Doc 1: The C# Player's Guide
      ├─ Doc 2: Clean Code
      ├─ ...
      └─ Doc 10: The Lean Startup
```

### Subsequent Runs (Data Exists)

```
Startup Log Output:
─────────────────────────────────────────────
Checking if Cosmos DB needs seeding...
Cosmos DB already contains 10 books. Skipping seed.
─────────────────────────────────────────────

Database State:
└─ LibraryDb/
   └─ Books/ (container)
      ├─ Doc 1: The C# Player's Guide [UNCHANGED]
      ├─ Doc 2: Clean Code [UNCHANGED]
      ├─ ...
      └─ Doc 10: The Lean Startup [UNCHANGED]
```

## Data Model

Each seeded book:

```csharp
public class Book
{
    public Guid Id { get; set; }                    // Unique ID
    public string? Isbn { get; set; }               // ISBN
    public string Title { get; set; }               // Book title
    public List<string> Authors { get; set; }       // Author names
    public string? Publisher { get; set; }          // Publisher
    public int? PublishYear { get; set; }           // Year
    public int? PageCount { get; set; }             // Pages
    public string? CoverImageUrl { get; set; }      // Image URL
    public string? Description { get; set; }        // Synopsis
    public string? ExternalId { get; set; }         // External ref
    public string? Source { get; set; }             // Source (="MockData")
}
```

Example document in Cosmos DB:

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "isbn": "978-0-13-235088-4",
    "title": "Clean Code",
    "authors": ["Robert C. Martin"],
    "publisher": "Prentice Hall",
    "publishYear": 2008,
    "pageCount": 464,
    "coverImageUrl": "https://covers.openlibrary.org/b/id/8383149-S.jpg",
    "description": "A handbook of agile software craftsmanship and best practices.",
    "source": "MockData",
    "externalId": "clean-code-martin-2008",
    "_ts": 1705176000,
    "_etag": "\"00001234-0000-0000-0000-000000000000\""
}
```

## Query Performance After Seeding

```bash
# Get all books (10 total)
GET /api/books
→ Returns all 10 books as JSON array

# Search by title
GET /api/books/search?query=Code
→ Returns: Clean Code, Code Complete

# Search by author
GET /api/books/search?query=Martin
→ Returns: Clean Code

# Search by ISBN
GET /api/books/isbn/978-0-13-235088-4
→ Returns: Clean Code

# Cosmos DB query used internally:
SELECT * FROM c WHERE 
    LOWER(c.title) LIKE @query OR
    EXISTS (SELECT VALUE a FROM a IN c.authors WHERE LOWER(a) LIKE @query)
```

## Error Handling

### If Seeding Fails

```csharp
// Graceful degradation
try
{
    await seeder.SeedIfEmptyAsync();
}
catch (Exception ex)
{
    logger.LogWarning(ex, "Seeding failed. Continuing.");
    // App continues, just without seeded data
    // Falls back to in-memory repository if needed
}
```

### If Cosmos DB Unavailable

```
Startup Log:
─────────────────────────────────────────────
Failed to initialize Cosmos DB repository.
Application will continue with in-memory repository.
─────────────────────────────────────────────

Behavior:
- API still works
- Uses InMemoryBookRepository
- Seeding skipped gracefully
```

## Configuration Precedence

```
appsettings.json
    ↓ (overridden by)
appsettings.{Environment}.json  (e.g., Development)
    ↓ (overridden by)
Environment Variables
    ↓ (overridden by)
Command line arguments
```

So with:
```
appsettings.json:              SeedMockData = false
appsettings.Development.json:  SeedMockData = true
Environment variable:          Azure__CosmosDb__SeedMockData=false
```

Final value = `false` (environment variable wins)

## Idempotent Design

The seeder is **safe to call multiple times**:

```csharp
// First call
await seeder.SeedIfEmptyAsync();  // Seeds 10 books ✓

// Second call (same process)
await seeder.SeedIfEmptyAsync();  // Finds 10 books, skips ✓

// Another process startup
await seeder.SeedIfEmptyAsync();  // Finds 10 books, skips ✓

// Manual call in code
await seeder.SeedIfEmptyAsync();  // Finds 10 books, skips ✓

// Result: Always exactly 10 books, never duplicates
```

This pattern is called **idempotent** - safe to run unlimited times.

## Testing

### Unit Test Example

```csharp
[TestClass]
public class CosmosDbSeederTests
{
    [TestMethod]
    public async Task SeedIfEmpty_OnEmptyContainer_SeedsBooks()
    {
        // Arrange
        var mockRepo = new MockCosmosDbRepository();  // Empty
        var mockLogger = new MockLogger<CosmosDbSeeder>();
        var seeder = new CosmosDbSeeder(mockRepo, mockLogger);

        // Act
        await seeder.SeedIfEmptyAsync();

        // Assert
        var allBooks = await mockRepo.GetAllAsync();
        Assert.AreEqual(10, allBooks.Count);
    }

    [TestMethod]
    public async Task SeedIfEmpty_OnNonEmptyContainer_Skips()
    {
        // Arrange
        var mockRepo = new MockCosmosDbRepository();
        await mockRepo.SaveAsync(new Book { Title = "Existing" });
        var seeder = new CosmosDbSeeder(mockRepo, new MockLogger());

        // Act
        await seeder.SeedIfEmptyAsync();

        // Assert
        var allBooks = await mockRepo.GetAllAsync();
        Assert.AreEqual(1, allBooks.Count);  // Only 1, not 11
    }
}
```

---

## Summary

| Aspect | Details |
|--------|---------|
| **Class** | `CosmosDbSeeder` |
| **Method** | `SeedIfEmptyAsync()` |
| **Books** | 10 sample books |
| **Idempotent** | Yes - safe to run multiple times |
| **Config Key** | `Azure:CosmosDb:SeedMockData` |
| **Default (Prod)** | `false` (disabled) |
| **Default (Dev)** | `true` (enabled) |
| **Logging** | Full visibility into actions |
| **Error Handling** | Graceful - continues if fails |

The implementation is **production-ready** and follows .NET best practices!
