using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Application.Abstractions;

/// <summary>
/// Repository interface for library data operations
/// </summary>
public interface ILibraryRepository
{
    /// <summary>
    /// Get all libraries
    /// </summary>
    Task<IEnumerable<Library>> GetAllAsync();

    /// <summary>
    /// Get a library by ID
    /// </summary>
    Task<Library?> GetByIdAsync(Guid id);

    /// <summary>
    /// Get libraries by owner
    /// </summary>
    Task<IEnumerable<Library>> GetByOwnerAsync(string owner);

    /// <summary>
    /// Create a new library
    /// </summary>
    Task<Library> CreateAsync(Library library);

    /// <summary>
    /// Update an existing library
    /// </summary>
    Task<Library?> UpdateAsync(Library library);

    /// <summary>
    /// Delete a library by ID
    /// </summary>
    Task<bool> DeleteAsync(Guid id);

    /// <summary>
    /// Add books to a library
    /// </summary>
    Task<Library?> AddBooksAsync(Guid libraryId, List<Guid> bookIds);

    /// <summary>
    /// Remove books from a library
    /// </summary>
    Task<Library?> RemoveBooksAsync(Guid libraryId, List<Guid> bookIds);
}
