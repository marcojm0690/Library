using MongoDB.Driver;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

public class MongoDbUserRepository : IUserRepository
{
    private readonly IMongoCollection<User> _users;

    public MongoDbUserRepository(IMongoDatabase database)
    {
        _users = database.GetCollection<User>("Users");
        
        // Create indexes
        var indexKeysDefinition = Builders<User>.IndexKeys
            .Ascending(u => u.ExternalId)
            .Ascending(u => u.Provider);
        var indexOptions = new CreateIndexOptions { Unique = true };
        var indexModel = new CreateIndexModel<User>(indexKeysDefinition, indexOptions);
        _users.Indexes.CreateOneAsync(indexModel);
    }

    public async Task<User?> GetByIdAsync(Guid id)
    {
        return await _users.Find(u => u.Id == id).FirstOrDefaultAsync();
    }

    public async Task<User?> GetByExternalIdAsync(string externalId, string provider)
    {
        return await _users.Find(u => u.ExternalId == externalId && u.Provider == provider)
            .FirstOrDefaultAsync();
    }

    public async Task<User> CreateAsync(User user)
    {
        user.Id = Guid.NewGuid();
        user.CreatedAt = DateTime.UtcNow;
        user.LastLoginAt = DateTime.UtcNow;
        await _users.InsertOneAsync(user);
        return user;
    }

    public async Task UpdateAsync(User user)
    {
        await _users.ReplaceOneAsync(u => u.Id == user.Id, user);
    }
}
