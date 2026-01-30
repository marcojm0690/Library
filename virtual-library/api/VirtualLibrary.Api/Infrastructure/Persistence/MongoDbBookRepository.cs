using MongoDB.Driver;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// MongoDB/Cosmos DB (MongoDB API) implementation of IBookRepository.
/// </summary>
public class MongoDbBookRepository : IBookRepository, IDisposable
{
    /// <summary>
    /// Delete all books where Source == "ISBNdb"
    /// </summary>
    public async Task<long> DeleteAllIsbndbBooksAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var filter = Builders<MongoBook>.Filter.Eq(b => b.Source, "ISBNdb");
            var result = await _collection.DeleteManyAsync(filter, cancellationToken);
            _logger.LogInformation("Deleted {Count} books with Source=ISBNdb", result.DeletedCount);
            return result.DeletedCount;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting ISBNdb books");
            throw;
        }
    }
    private readonly IMongoClient _mongoClient;
    private readonly IMongoDatabase _database;
    private readonly IMongoCollection<MongoBook> _collection;
    private readonly ILogger<MongoDbBookRepository> _logger;

    public MongoDbBookRepository(
        string connectionString,
        string databaseName,
        string collectionName,
        ILogger<MongoDbBookRepository> logger)
    {
        _logger = logger;

        try
        {
            _mongoClient = new MongoClient(connectionString);
            _database = _mongoClient.GetDatabase(databaseName);
            _collection = _database.GetCollection<MongoBook>(collectionName);

            _logger.LogInformation(
                "MongoDB repository initialized - Database: {Database}, Collection: {Collection}",
                databaseName, collectionName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize MongoDB repository");
            throw;
        }
    }

    public async Task<Book?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        try
        {
            var filter = Builders<MongoBook>.Filter.Eq(b => b.Id, id);
            var mongoBook = await _collection.Find(filter).FirstOrDefaultAsync(cancellationToken);
            return mongoBook?.ToBook();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving book by ID: {BookId}", id);
            return null;
        }
    }

    public async Task<Book?> GetByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        try
        {
            // Clean the ISBN for comparison (remove dashes and spaces)
            var cleanIsbn = isbn.Replace("-", "").Replace(" ", "").Trim();
            
            // Try exact match first (fast)
            var exactFilter = Builders<MongoBook>.Filter.Eq(b => b.Isbn, isbn);
            var mongoBook = await _collection.Find(exactFilter).FirstOrDefaultAsync(cancellationToken);
            
            if (mongoBook != null)
            {
                return mongoBook.ToBook();
            }
            
            // If not found, try searching with cleaned ISBN
            var cleanFilter = Builders<MongoBook>.Filter.Eq(b => b.Isbn, cleanIsbn);
            mongoBook = await _collection.Find(cleanFilter).FirstOrDefaultAsync(cancellationToken);
            
            if (mongoBook != null)
            {
                return mongoBook.ToBook();
            }
            
            // Last resort: fetch all and compare normalized ISBNs
            var allBooks = await _collection.Find(_ => true).ToListAsync(cancellationToken);
            mongoBook = allBooks.FirstOrDefault(b => 
                b.Isbn?.Replace("-", "").Replace(" ", "").Equals(cleanIsbn, StringComparison.OrdinalIgnoreCase) == true
            );
            
            return mongoBook?.ToBook();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving book by ISBN: {Isbn}", isbn);
            return null;
        }
    }

    public async Task<List<Book>> SearchAsync(string query, CancellationToken cancellationToken = default)
    {
        try
        {
            var filter = Builders<MongoBook>.Filter.Or(
                Builders<MongoBook>.Filter.Regex(b => b.Title, new BsonRegularExpression(query, "i")),
                Builders<MongoBook>.Filter.Regex(b => b.Publisher, new BsonRegularExpression(query, "i"))
            );

            var mongoBooks = await _collection.Find(filter).ToListAsync(cancellationToken);
            return mongoBooks.Select(b => b.ToBook()).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching books with query: {Query}", query);
            return new List<Book>();
        }
    }

    public async Task<Book> SaveAsync(Book book, CancellationToken cancellationToken = default)
    {
        try
        {
            var mongoBook = MongoBook.FromBook(book);
            
            var filter = Builders<MongoBook>.Filter.Eq(b => b.Id, book.Id);
            var options = new ReplaceOptions { IsUpsert = true };
            
            await _collection.ReplaceOneAsync(filter, mongoBook, options, cancellationToken);
            
            _logger.LogInformation("Book saved successfully: {BookId}", book.Id);
            return book;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving book: {BookId}", book.Id);
            throw;
        }
    }

    public async Task<Book> UpdateAsync(Book book, CancellationToken cancellationToken = default)
    {
        try
        {
            var mongoBook = MongoBook.FromBook(book);
            
            var filter = Builders<MongoBook>.Filter.Eq(b => b.Id, book.Id);
            var result = await _collection.ReplaceOneAsync(filter, mongoBook, cancellationToken: cancellationToken);
            
            if (result.MatchedCount == 0)
            {
                _logger.LogWarning("Book not found for update: {BookId}", book.Id);
                throw new InvalidOperationException($"Book with ID {book.Id} not found");
            }
            
            _logger.LogInformation("Book updated successfully: {BookId}", book.Id);
            return book;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating book: {BookId}", book.Id);
            throw;
        }
    }

    public async Task<List<Book>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var mongoBooks = await _collection.Find(_ => true).ToListAsync(cancellationToken);
            return mongoBooks.Select(b => b.ToBook()).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all books");
            return new List<Book>();
        }
    }

    public async Task InitializeAsync()
    {
        try
        {
            // Create indexes for better query performance
            var isbnIndex = Builders<MongoBook>.IndexKeys.Ascending(b => b.Isbn);
            await _collection.Indexes.CreateOneAsync(new CreateIndexModel<MongoBook>(isbnIndex));

            var titleIndex = Builders<MongoBook>.IndexKeys.Ascending(b => b.Title);
            await _collection.Indexes.CreateOneAsync(new CreateIndexModel<MongoBook>(titleIndex));

            _logger.LogInformation("MongoDB indexes created successfully");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to create indexes (may already exist)");
        }
    }

    public void Dispose()
    {
        // MongoDB client handles connection pooling, no explicit disposal needed
        GC.SuppressFinalize(this);
    }

    /// <summary>
    /// MongoDB document model for books
    /// </summary>
    private class MongoBook
    {
        [BsonId]
        [BsonGuidRepresentation(GuidRepresentation.Standard)]
        public Guid Id { get; set; }

        [BsonElement("isbn")]
        public string Isbn { get; set; } = string.Empty;

        [BsonElement("title")]
        public string Title { get; set; } = string.Empty;

        [BsonElement("authors")]
        public List<string> Authors { get; set; } = new();

        [BsonElement("publisher")]
        public string? Publisher { get; set; }

        [BsonElement("publishYear")]
        public int? PublishYear { get; set; }

        [BsonElement("pageCount")]
        public int? PageCount { get; set; }

        [BsonElement("coverImageUrl")]
        public string? CoverImageUrl { get; set; }

        [BsonElement("description")]
        public string? Description { get; set; }

        [BsonElement("source")]
        public string Source { get; set; } = string.Empty;

        [BsonElement("externalId")]
        public string? ExternalId { get; set; }

        public static MongoBook FromBook(Book book)
        {
            return new MongoBook
            {
                Id = book.Id,
                Isbn = book.Isbn,
                Title = book.Title,
                Authors = book.Authors.ToList(),
                Publisher = book.Publisher,
                PublishYear = book.PublishYear,
                PageCount = book.PageCount,
                CoverImageUrl = book.CoverImageUrl,
                Description = book.Description,
                Source = book.Source ?? string.Empty,
                ExternalId = book.ExternalId
            };
        }

        public Book ToBook()
        {
            return new Book
            {
                Id = Id,
                Isbn = Isbn,
                Title = Title,
                Authors = Authors,
                Publisher = Publisher,
                PublishYear = PublishYear,
                PageCount = PageCount,
                CoverImageUrl = CoverImageUrl,
                Description = Description,
                Source = string.IsNullOrEmpty(Source) ? null : Source,
                ExternalId = ExternalId
            };
        }
    }
}
