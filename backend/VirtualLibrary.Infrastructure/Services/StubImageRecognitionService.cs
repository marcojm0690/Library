using VirtualLibrary.Application.Interfaces;
using VirtualLibrary.Domain.Entities;

namespace VirtualLibrary.Infrastructure.Services;

public class StubImageRecognitionService : IImageRecognitionService
{
    public Task<List<Book>> SearchBooksByCoverImageAsync(string imageBase64, CancellationToken cancellationToken = default)
    {
        // Stub implementation - returns mock data for demonstration
        if (string.IsNullOrWhiteSpace(imageBase64))
        {
            return Task.FromResult(new List<Book>());
        }

        var books = new List<Book>
        {
            new Book
            {
                ISBN = "9780134685991",
                Title = "Effective Java (3rd Edition)",
                Author = "Joshua Bloch",
                Publisher = "Addison-Wesley",
                PublicationYear = 2018,
                Description = "This is a stub implementation. In a real application, this would use OCR and image recognition to identify books from cover images.",
                CoverImageUrl = "https://via.placeholder.com/300x450.png?text=Book+1",
                Categories = new List<string> { "Programming", "Java" }
            },
            new Book
            {
                ISBN = "9780135957059",
                Title = "The Pragmatic Programmer",
                Author = "David Thomas, Andrew Hunt",
                Publisher = "Addison-Wesley",
                PublicationYear = 2019,
                Description = "Another sample book from the stub implementation.",
                CoverImageUrl = "https://via.placeholder.com/300x450.png?text=Book+2",
                Categories = new List<string> { "Programming", "Software Engineering" }
            }
        };

        return Task.FromResult(books);
    }
}
