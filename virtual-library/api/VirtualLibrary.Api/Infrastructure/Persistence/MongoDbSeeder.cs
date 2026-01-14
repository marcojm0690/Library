using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// Seeds mock book data into MongoDB/Cosmos DB for development and testing.
/// Safe to run multiple times - checks if database is empty before seeding.
/// </summary>
public class MongoDbSeeder
{
    private readonly IBookRepository _repository;
    private readonly ILogger<MongoDbSeeder> _logger;

    public MongoDbSeeder(IBookRepository repository, ILogger<MongoDbSeeder> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    /// <summary>
    /// Seeds mock book data if collection is empty.
    /// Idempotent - safe to call multiple times.
    /// </summary>
    public async Task SeedIfEmptyAsync()
    {
        try
        {
            _logger.LogInformation("Checking if MongoDB needs seeding...");

            var existingBooks = await _repository.GetAllAsync();
            var booksList = existingBooks.ToList();

            if (booksList.Any())
            {
                _logger.LogInformation("MongoDB already contains {Count} books. Skipping seed.", booksList.Count);
                return;
            }

            _logger.LogInformation("MongoDB is empty. Seeding mock data...");
            await SeedMockBooksAsync();
            _logger.LogInformation("Seeding completed successfully. Added 10 books.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during MongoDB seeding");
            throw;
        }
    }

    private async Task SeedMockBooksAsync()
    {
        var mockBooks = GetMockBooks();

        foreach (var book in mockBooks)
        {
            await _repository.SaveAsync(book);
            _logger.LogDebug("Seeded book: {Title} by {Authors}", book.Title, string.Join(", ", book.Authors));
        }
    }

    private static List<Book> GetMockBooks()
    {
        return new List<Book>
        {
            // Programming Books
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-13-468599-1",
                Title = "The C# Player's Guide",
                Authors = new List<string> { "RB Whitaker" },
                Publisher = "Independent",
                PublishYear = 2019,
                PageCount = 456,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8374929-S.jpg",
                Description = "A unique way to learn C# programming through games and challenges.",
                Source = "MockData",
                ExternalId = "csplayers-guide-2019"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-13-235088-4",
                Title = "Clean Code",
                Authors = new List<string> { "Robert C. Martin" },
                Publisher = "Prentice Hall",
                PublishYear = 2008,
                PageCount = 464,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8383149-S.jpg",
                Description = "A handbook of agile software craftsmanship and best practices.",
                Source = "MockData",
                ExternalId = "clean-code-martin-2008"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-07-142966-5",
                Title = "Code Complete",
                Authors = new List<string> { "Steve McConnell" },
                Publisher = "Microsoft Press",
                PublishYear = 2004,
                PageCount = 960,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8381325-S.jpg",
                Description = "A comprehensive guide to software construction and practical techniques.",
                Source = "MockData",
                ExternalId = "code-complete-2004"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-13-110362-7",
                Title = "The Pragmatic Programmer",
                Authors = new List<string> { "Andrew Hunt", "David Thomas" },
                Publisher = "Addison-Wesley",
                PublishYear = 2000,
                PageCount = 352,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8379916-S.jpg",
                Description = "From journeyman to master - your journey to becoming a pragmatic programmer.",
                Source = "MockData",
                ExternalId = "pragmatic-programmer-2000"
            },

            // Fiction Books
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-06-112008-4",
                Title = "To Kill a Mockingbird",
                Authors = new List<string> { "Harper Lee" },
                Publisher = "Harper Perennial Modern Classics",
                PublishYear = 1960,
                PageCount = 324,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8376504-S.jpg",
                Description = "A classic of modern American literature that has won the Pulitzer Prize.",
                Source = "MockData",
                ExternalId = "mockingbird-1960"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-451-52493-2",
                Title = "1984",
                Authors = new List<string> { "George Orwell" },
                Publisher = "Signet Classics",
                PublishYear = 1949,
                PageCount = 328,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8378638-S.jpg",
                Description = "A dystopian social science fiction novel and cautionary tale.",
                Source = "MockData",
                ExternalId = "1984-orwell-1949"
            },

            // Science Books
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-553-38016-3",
                Title = "A Brief History of Time",
                Authors = new List<string> { "Stephen Hawking" },
                Publisher = "Bantam",
                PublishYear = 1988,
                PageCount = 256,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8377821-S.jpg",
                Description = "From the Big Bang to black holes - a landmark volume in science writing.",
                Source = "MockData",
                ExternalId = "brief-history-time-1988"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-345-33312-0",
                Title = "Cosmos",
                Authors = new List<string> { "Carl Sagan" },
                Publisher = "Ballantine Books",
                PublishYear = 1980,
                PageCount = 384,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8377094-S.jpg",
                Description = "A journey through space and time exploring the universe and our place in it.",
                Source = "MockData",
                ExternalId = "cosmos-sagan-1980"
            },

            // Business Books
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-06-662099-2",
                Title = "Good to Great",
                Authors = new List<string> { "Jim Collins" },
                Publisher = "Harper Business",
                PublishYear = 2001,
                PageCount = 320,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8380145-S.jpg",
                Description = "Why some companies make the leap to great and others don't.",
                Source = "MockData",
                ExternalId = "good-to-great-2001"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-307-88789-4",
                Title = "The Lean Startup",
                Authors = new List<string> { "Eric Ries" },
                Publisher = "Crown Business",
                PublishYear = 2011,
                PageCount = 336,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8382617-S.jpg",
                Description = "How today's entrepreneurs use continuous innovation to create radically successful businesses.",
                Source = "MockData",
                ExternalId = "lean-startup-2011"
            }
        };
    }
}
