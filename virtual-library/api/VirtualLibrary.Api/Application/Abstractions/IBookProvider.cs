using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Application.Abstractions;

/// <summary>
/// Abstraction for external book data providers (Google Books, Open Library, etc.)
/// Implementations should handle API communication and data mapping
/// </summary>
public interface IBookProvider
{
    /// <summary>
    /// Provider name for identification (e.g., "GoogleBooks", "OpenLibrary")
    /// </summary>
    string ProviderName { get; }

    /// <summary>
    /// Search for a book by its ISBN
    /// </summary>
    /// <param name="isbn">ISBN-10 or ISBN-13</param>
    /// <returns>Book information if found, null otherwise</returns>
    Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default);

    /// <summary>
    /// Search for books using text extracted from the cover (title, author, etc.)
    /// </summary>
    /// <param name="searchText">Text extracted via OCR from book cover</param>
    /// <returns>List of matching books</returns>
    Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default);
}

/// <summary>
/// Repository abstraction for book persistence
/// Can be implemented with Entity Framework, Dapper, or any other data access technology
/// </summary>
public interface IBookRepository
{
    /// <summary>
    /// Get a book by its internal system ID
    /// </summary>
    Task<Book?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>
    /// Get a book by its ISBN
    /// </summary>
    Task<Book?> GetByIsbnAsync(string isbn, CancellationToken cancellationToken = default);

    /// <summary>
    /// Search books by title or author
    /// </summary>
    Task<List<Book>> SearchAsync(string query, CancellationToken cancellationToken = default);

    /// <summary>
    /// Add or update a book in the repository
    /// </summary>
    Task<Book> SaveAsync(Book book, CancellationToken cancellationToken = default);

    /// <summary>
    /// Get all books in the library
    /// </summary>
    Task<List<Book>> GetAllAsync(CancellationToken cancellationToken = default);
}
