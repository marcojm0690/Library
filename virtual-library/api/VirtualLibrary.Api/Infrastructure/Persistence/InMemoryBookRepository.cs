using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// In-memory implementation of IBookRepository for prototyping.
/// Replace with Entity Framework Core or other persistence mechanism in production.
/// </summary>
public class InMemoryBookRepository : IBookRepository
{
    private readonly Dictionary<Guid, Book> _books = new();
    private readonly object _lock = new();

    public Task<Book?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            _books.TryGetValue(id, out var book);
            return Task.FromResult(book);
        }
    }

    public Task<Book?> GetByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            var book = _books.Values.FirstOrDefault(b => 
                b.Isbn?.Replace("-", "").Replace(" ", "").Equals(isbn.Replace("-", "").Replace(" ", ""), StringComparison.OrdinalIgnoreCase) == true);
            return Task.FromResult(book);
        }
    }

    public Task<List<Book>> SearchAsync(string query, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            var lowerQuery = query.ToLowerInvariant();
            var results = _books.Values
                .Where(b => 
                    b.Title.ToLowerInvariant().Contains(lowerQuery) ||
                    b.Authors.Any(a => a.ToLowerInvariant().Contains(lowerQuery)))
                .ToList();
            
            return Task.FromResult(results);
        }
    }

    public Task<Book> SaveAsync(Book book, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            if (book.Id == Guid.Empty)
            {
                book.Id = Guid.NewGuid();
            }

            _books[book.Id] = book;
            return Task.FromResult(book);
        }
    }

    public Task<List<Book>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            return Task.FromResult(_books.Values.ToList());
        }
    }
}
