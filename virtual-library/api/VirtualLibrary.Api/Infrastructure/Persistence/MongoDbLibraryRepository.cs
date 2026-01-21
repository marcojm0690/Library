using MongoDB.Driver;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// MongoDB implementation of library repository
/// </summary>
public class MongoDbLibraryRepository : ILibraryRepository, IDisposable
{
    private readonly IMongoClient _mongoClient;
    private readonly IMongoDatabase _database;
    private readonly IMongoCollection<MongoLibrary> _collection;
    private readonly ILogger<MongoDbLibraryRepository> _logger;

    public MongoDbLibraryRepository(
        string connectionString,
        string databaseName,
        string collectionName,
        ILogger<MongoDbLibraryRepository> logger)
    {
        _logger = logger;

        try
        {
            _mongoClient = new MongoClient(connectionString);
            _database = _mongoClient.GetDatabase(databaseName);
            _collection = _database.GetCollection<MongoLibrary>(collectionName);

            _logger.LogInformation(
                "MongoDB library repository initialized - Database: {Database}, Collection: {Collection}",
                databaseName, collectionName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize MongoDB library repository");
            throw;
        }
    }

    public async Task<IEnumerable<Library>> GetAllAsync()
    {
        try
        {
            var mongoLibraries = await _collection.Find(_ => true).ToListAsync();
            return mongoLibraries.Select(ml => ml.ToLibrary());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all libraries");
            throw;
        }
    }

    public async Task<Library?> GetByIdAsync(Guid id)
    {
        try
        {
            var filter = Builders<MongoLibrary>.Filter.Eq(l => l.Id, id);
            var mongoLibrary = await _collection.Find(filter).FirstOrDefaultAsync();
            return mongoLibrary?.ToLibrary();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving library by ID: {Id}", id);
            throw;
        }
    }

    public async Task<IEnumerable<Library>> GetByOwnerAsync(string owner)
    {
        try
        {
            var filter = Builders<MongoLibrary>.Filter.Eq(l => l.Owner, owner);
            var mongoLibraries = await _collection.Find(filter).ToListAsync();
            return mongoLibraries.Select(ml => ml.ToLibrary());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving libraries by owner: {Owner}", owner);
            throw;
        }
    }

    public async Task<Library> CreateAsync(Library library)
    {
        try
        {
            library.Id = Guid.NewGuid();
            library.CreatedAt = DateTime.UtcNow;
            library.UpdatedAt = DateTime.UtcNow;

            var mongoLibrary = MongoLibrary.FromLibrary(library);
            await _collection.InsertOneAsync(mongoLibrary);

            _logger.LogInformation("Created library: {Name} (ID: {Id})", library.Name, library.Id);
            return library;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating library: {Name}", library.Name);
            throw;
        }
    }

    public async Task<Library?> UpdateAsync(Library library)
    {
        try
        {
            library.UpdatedAt = DateTime.UtcNow;

            var filter = Builders<MongoLibrary>.Filter.Eq(l => l.Id, library.Id);
            var mongoLibrary = MongoLibrary.FromLibrary(library);
            
            var result = await _collection.ReplaceOneAsync(filter, mongoLibrary);

            if (result.MatchedCount == 0)
            {
                _logger.LogWarning("Library not found for update: {Id}", library.Id);
                return null;
            }

            _logger.LogInformation("Updated library: {Id}", library.Id);
            return library;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating library: {Id}", library.Id);
            throw;
        }
    }

    public async Task<bool> DeleteAsync(Guid id)
    {
        try
        {
            var filter = Builders<MongoLibrary>.Filter.Eq(l => l.Id, id);
            var result = await _collection.DeleteOneAsync(filter);

            if (result.DeletedCount > 0)
            {
                _logger.LogInformation("Deleted library: {Id}", id);
                return true;
            }

            _logger.LogWarning("Library not found for deletion: {Id}", id);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting library: {Id}", id);
            throw;
        }
    }

    public async Task<Library?> AddBooksAsync(Guid libraryId, List<Guid> bookIds)
    {
        try
        {
            var filter = Builders<MongoLibrary>.Filter.Eq(l => l.Id, libraryId);
            var update = Builders<MongoLibrary>.Update
                .AddToSetEach(l => l.BookIds, bookIds)
                .Set(l => l.UpdatedAt, DateTime.UtcNow);

            var result = await _collection.FindOneAndUpdateAsync(
                filter, 
                update,
                new FindOneAndUpdateOptions<MongoLibrary> { ReturnDocument = ReturnDocument.After });

            if (result == null)
            {
                _logger.LogWarning("Library not found for adding books: {Id}", libraryId);
                return null;
            }

            _logger.LogInformation("Added {Count} books to library: {Id}", bookIds.Count, libraryId);
            return result.ToLibrary();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding books to library: {Id}", libraryId);
            throw;
        }
    }

    public async Task<Library?> RemoveBooksAsync(Guid libraryId, List<Guid> bookIds)
    {
        try
        {
            var filter = Builders<MongoLibrary>.Filter.Eq(l => l.Id, libraryId);
            var update = Builders<MongoLibrary>.Update
                .PullAll(l => l.BookIds, bookIds)
                .Set(l => l.UpdatedAt, DateTime.UtcNow);

            var result = await _collection.FindOneAndUpdateAsync(
                filter, 
                update,
                new FindOneAndUpdateOptions<MongoLibrary> { ReturnDocument = ReturnDocument.After });

            if (result == null)
            {
                _logger.LogWarning("Library not found for removing books: {Id}", libraryId);
                return null;
            }

            _logger.LogInformation("Removed {Count} books from library: {Id}", bookIds.Count, libraryId);
            return result.ToLibrary();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing books from library: {Id}", libraryId);
            throw;
        }
    }

    public void Dispose()
    {
        // MongoClient manages its own connections
        GC.SuppressFinalize(this);
    }
}

/// <summary>
/// MongoDB document model for library
/// </summary>
internal class MongoLibrary
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonElement("name")]
    public string Name { get; set; } = string.Empty;

    [BsonElement("description")]
    public string? Description { get; set; }

    [BsonElement("owner")]
    public string Owner { get; set; } = string.Empty;

    [BsonElement("createdAt")]
    public DateTime CreatedAt { get; set; }

    [BsonElement("updatedAt")]
    public DateTime UpdatedAt { get; set; }

    [BsonElement("bookIds")]
    public List<Guid> BookIds { get; set; } = new();

    [BsonElement("tags")]
    public List<string> Tags { get; set; } = new();

    [BsonElement("isPublic")]
    public bool IsPublic { get; set; }

    public Library ToLibrary() => new()
    {
        Id = Id,
        Name = Name,
        Description = Description,
        Owner = Owner,
        CreatedAt = CreatedAt,
        UpdatedAt = UpdatedAt,
        BookIds = BookIds,
        Tags = Tags,
        IsPublic = IsPublic
    };

    public static MongoLibrary FromLibrary(Library library) => new()
    {
        Id = library.Id,
        Name = library.Name,
        Description = library.Description,
        Owner = library.Owner,
        CreatedAt = library.CreatedAt,
        UpdatedAt = library.UpdatedAt,
        BookIds = library.BookIds,
        Tags = library.Tags,
        IsPublic = library.IsPublic
    };
}
