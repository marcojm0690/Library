using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// Seeds the in-memory book repository with mock data for development/testing.
/// Only used when Cosmos DB is not configured.
/// </summary>
public static class InMemorySeeder
{
    public static async Task SeedMockBooksAsync(IBookRepository repository)
    {
        var mockBooks = GetMockBooks();
        
        foreach (var book in mockBooks)
        {
            await repository.SaveAsync(book);
        }
    }

    private static List<Book> GetMockBooks()
    {
        return new List<Book>
        {
            // Programming
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
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8383134-S.jpg",
                Description = "Your journey to mastery in software development with practical tips.",
                Source = "MockData",
                ExternalId = "pragmatic-programmer-2000"
            },

            // Fiction
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-06-112008-4",
                Title = "To Kill a Mockingbird",
                Authors = new List<string> { "Harper Lee" },
                Publisher = "J.B. Lippincott",
                PublishYear = 1960,
                PageCount = 281,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8383135-S.jpg",
                Description = "A classic novel of racial injustice and childhood innocence in the American South.",
                Source = "MockData",
                ExternalId = "mockingbird-lee-1960"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-14-028329-7",
                Title = "1984",
                Authors = new List<string> { "George Orwell" },
                Publisher = "Penguin Books",
                PublishYear = 1949,
                PageCount = 328,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8381331-S.jpg",
                Description = "A dystopian social science fiction novel set in a totalitarian superstate.",
                Source = "MockData",
                ExternalId = "1984-orwell-1949"
            },

            // Science
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-525-55361-6",
                Title = "A Brief History of Time",
                Authors = new List<string> { "Stephen Hawking" },
                Publisher = "Bantam",
                PublishYear = 1988,
                PageCount = 212,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8383144-S.jpg",
                Description = "From the Big Bang to Black Holes - exploring the universe's greatest mysteries.",
                Source = "MockData",
                ExternalId = "brief-history-hawking-1988"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-06-085085-5",
                Title = "Cosmos",
                Authors = new List<string> { "Carl Sagan" },
                Publisher = "Random House",
                PublishYear = 1980,
                PageCount = 953,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8381332-S.jpg",
                Description = "A journey through space and time exploring the universe and humanity's place in it.",
                Source = "MockData",
                ExternalId = "cosmos-sagan-1980"
            },

            // Business
            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-0-06-019373-0",
                Title = "Good to Great",
                Authors = new List<string> { "Jim Collins" },
                Publisher = "HarperBusiness",
                PublishYear = 2001,
                PageCount = 300,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8383145-S.jpg",
                Description = "Why some companies make the leap and others don't - a business analysis.",
                Source = "MockData",
                ExternalId = "good-to-great-collins-2001"
            },

            new Book
            {
                Id = Guid.NewGuid(),
                Isbn = "978-1-59184-618-1",
                Title = "The Lean Startup",
                Authors = new List<string> { "Eric Ries" },
                Publisher = "Crown Business",
                PublishYear = 2011,
                PageCount = 544,
                CoverImageUrl = "https://covers.openlibrary.org/b/id/8383146-S.jpg",
                Description = "How modern entrepreneurs use continuous innovation to build successful businesses.",
                Source = "MockData",
                ExternalId = "lean-startup-ries-2011"
            }
        };
    }
}
