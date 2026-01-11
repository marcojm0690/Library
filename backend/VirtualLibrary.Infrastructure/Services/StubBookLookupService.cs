using VirtualLibrary.Application.Interfaces;
using VirtualLibrary.Domain.Entities;

namespace VirtualLibrary.Infrastructure.Services;

public class StubBookLookupService : IBookLookupService
{
    public Task<Book?> LookupBookByISBNAsync(string isbn, CancellationToken cancellationToken = default)
    {
        // Stub implementation - returns mock data for demonstration
        if (string.IsNullOrWhiteSpace(isbn))
        {
            return Task.FromResult<Book?>(null);
        }

        var book = new Book
        {
            ISBN = isbn,
            Title = "Sample Book Title",
            Author = "Sample Author",
            Publisher = "Sample Publisher",
            PublicationYear = 2024,
            Description = "This is a stub implementation. In a real application, this would fetch book data from an external API like Google Books or Open Library.",
            CoverImageUrl = "https://via.placeholder.com/300x450.png?text=Book+Cover",
            Categories = new List<string> { "Fiction", "Technology" }
        };

        return Task.FromResult<Book?>(book);
    }
}
