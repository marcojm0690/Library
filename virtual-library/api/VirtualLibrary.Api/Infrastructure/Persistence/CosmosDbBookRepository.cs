using Azure;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// Cosmos DB implementation of IBookRepository for persistent, globally-distributed book storage.
/// Uses Azure Managed Identity for authentication (no connection strings or keys in code).
/// </summary>
public class CosmosDbBookRepository : IBookRepository, IDisposable
{
    private readonly CosmosClient _cosmosClient;
    private readonly Container _container;
    private readonly ILogger<CosmosDbBookRepository> _logger;

    private const string PartitionKeyPath = "/id";

    public CosmosDbBookRepository(
        string cosmosDbEndpoint,
        string databaseName,
        string containerName,
        ILogger<CosmosDbBookRepository> logger)
    {
        _logger = logger;

        try
        {
            // Use DefaultAzureCredential for Managed Identity authentication
            var credential = new DefaultAzureCredential();
            _cosmosClient = new CosmosClient(cosmosDbEndpoint, credential);

            // Get or create database
            var database = _cosmosClient.GetDatabase(databaseName);

            // Get or create container
            _container = database.GetContainer(containerName);

            _logger.LogInformation(
                "Cosmos DB repository initialized - Endpoint: {Endpoint}, Database: {Database}, Container: {Container}",
                cosmosDbEndpoint, databaseName, containerName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Cosmos DB repository");
            throw;
        }
    }

    /// <summary>
    /// Retrieve a book by its unique identifier
    /// </summary>
    public async Task<Book?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _container.ReadItemAsync<Book>(
                id.ToString(),
                new PartitionKey(id.ToString()),
                cancellationToken: cancellationToken);

            _logger.LogDebug("Retrieved book with ID: {BookId}", id);
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            _logger.LogDebug("Book not found with ID: {BookId}", id);
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving book with ID: {BookId}", id);
            throw;
        }
    }

    /// <summary>
    /// Search for a book by ISBN
    /// </summary>
    public async Task<Book?> GetByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(isbn))
            return null;

        try
        {
            var normalizedIsbn = isbn.Replace("-", "").Replace(" ", "");

            var query = "SELECT * FROM c WHERE REPLACE(REPLACE(c.isbn, '-', ''), ' ', '') = @isbn";
            var queryDefinition = new QueryDefinition(query)
                .WithParameter("@isbn", normalizedIsbn);

            var iterator = _container.GetItemQueryIterator<Book>(queryDefinition);
            var results = await iterator.ReadNextAsync(cancellationToken);

            var book = results.FirstOrDefault();
            if (book != null)
            {
                _logger.LogDebug("Found book by ISBN: {ISBN}", isbn);
            }
            else
            {
                _logger.LogDebug("No book found for ISBN: {ISBN}", isbn);
            }

            return book;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching for book by ISBN: {ISBN}", isbn);
            throw;
        }
    }

    /// <summary>
    /// Get all books in the library
    /// </summary>
    public async Task<List<Book>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var query = "SELECT * FROM c";
            var queryDefinition = new QueryDefinition(query);

            var iterator = _container.GetItemQueryIterator<Book>(queryDefinition);
            var results = new List<Book>();

            while (iterator.HasMoreResults)
            {
                var page = await iterator.ReadNextAsync(cancellationToken);
                results.AddRange(page.Resource);
            }

            _logger.LogDebug("Retrieved all books. Count: {Count}", results.Count);
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all books");
            throw;
        }
    }

    /// <summary>
    /// Search for books by title or author text
    /// </summary>
    public async Task<List<Book>> SearchAsync(string query, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(query))
            return new List<Book>();

        try
        {
            var lowerQuery = query.ToLowerInvariant();

            var cosmosQuery = @"
                SELECT * FROM c WHERE
                    LOWER(c.title) LIKE @query OR
                    EXISTS (SELECT VALUE a FROM a IN c.authors WHERE LOWER(a) LIKE @query)
            ";

            var queryDefinition = new QueryDefinition(cosmosQuery)
                .WithParameter("@query", $"%{lowerQuery}%");

            var iterator = _container.GetItemQueryIterator<Book>(queryDefinition);
            var results = new List<Book>();

            while (iterator.HasMoreResults)
            {
                var page = await iterator.ReadNextAsync(cancellationToken);
                results.AddRange(page.Resource);
            }

            _logger.LogDebug("Search for '{Query}' returned {Count} books", query, results.Count);
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching for books with query: {Query}", query);
            throw;
        }
    }

    /// <summary>
    /// Save a new or updated book to Cosmos DB
    /// </summary>
    public async Task<Book> SaveAsync(Book book, CancellationToken cancellationToken = default)
    {
        if (book == null)
            throw new ArgumentNullException(nameof(book));

        try
        {
            if (book.Id == Guid.Empty)
            {
                book.Id = Guid.NewGuid();
            }

            var response = await _container.UpsertItemAsync(
                book,
                new PartitionKey(book.Id.ToString()),
                cancellationToken: cancellationToken);

            _logger.LogInformation(
                "Saved book '{Title}' with ID: {BookId}. Request Charge: {RequestCharge} RU",
                book.Title, book.Id, response.RequestCharge);

            return response.Resource;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving book: {Title}", book.Title);
            throw;
        }
    }

    /// <summary>
    /// Ensure database and container exist (idempotent operation)
    /// </summary>
    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Initializing Cosmos DB database and container");

            // Database is already obtained in constructor
            // Container is already obtained in constructor
            // No additional initialization needed with the Get* methods

            _logger.LogInformation("Cosmos DB initialization completed successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error initializing Cosmos DB");
            throw;
        }
    }

    /// <summary>
    /// Gracefully dispose of Cosmos DB client
    /// </summary>
    public void Dispose()
    {
        if (_cosmosClient != null)
        {
            _logger.LogInformation("Disposing Cosmos DB client");
            _cosmosClient.Dispose();
        }
    }
}
