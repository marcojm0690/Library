using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Application.Abstractions;

/// <summary>
/// Repository interface for user data operations
/// </summary>
public interface IUserRepository
{
    /// <summary>
    /// Get a user by their unique identifier
    /// </summary>
    Task<User?> GetByIdAsync(Guid id);

    /// <summary>
    /// Get a user by their external provider ID
    /// </summary>
    Task<User?> GetByExternalIdAsync(string externalId, string provider);

    /// <summary>
    /// Create a new user
    /// </summary>
    Task<User> CreateAsync(User user);

    /// <summary>
    /// Update an existing user
    /// </summary>
    Task UpdateAsync(User user);
}
