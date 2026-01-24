using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Application.Books.SearchByCover;

/// <summary>
/// Service responsible for searching books by cover text extracted via OCR.
/// Parses OCR text to identify title/author and searches across providers.
/// </summary>
public class SearchByCoverService
{
    private readonly IEnumerable<IBookProvider> _bookProviders;
    private readonly IBookRepository _bookRepository;
    private readonly ILogger<SearchByCoverService> _logger;

    public SearchByCoverService(
        IEnumerable<IBookProvider> bookProviders,
        IBookRepository bookRepository,
        ILogger<SearchByCoverService> logger)
    {
        _bookProviders = bookProviders;
        _bookRepository = bookRepository;
        _logger = logger;
    }

    /// <summary>
    /// Search for books based on OCR-extracted text from a cover image.
    /// Returns a list of potential matches ranked by relevance.
    /// </summary>
    public async Task<SearchBooksResponse> ExecuteAsync(string extractedText, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(extractedText))
        {
            _logger.LogWarning("Cover search called with empty text");
            return new SearchBooksResponse { Books = new(), TotalResults = 0 };
        }

        // Clean and normalize the extracted text
        var searchText = CleanExtractedText(extractedText);
        _logger.LogInformation("Searching for book with cover text: {Text}", searchText);

        var allResults = new List<Book>();

        // First check local repository
        var localResults = await _bookRepository.SearchAsync(searchText, cancellationToken);
        if (localResults.Any())
        {
            _logger.LogInformation("Found {Count} results in local repository", localResults.Count);
            allResults.AddRange(localResults);
        }

        // Search external providers
        foreach (var provider in _bookProviders)
        {
            try
            {
                _logger.LogInformation("Searching {Provider} for cover text", provider.ProviderName);
                var providerResults = await provider.SearchByTextAsync(searchText, cancellationToken);
                
                if (providerResults.Any())
                {
                    _logger.LogInformation("Found {Count} results from {Provider}", providerResults.Count, provider.ProviderName);
                    allResults.AddRange(providerResults);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error searching {Provider} for cover text", provider.ProviderName);
                // Continue to next provider
            }
        }

        // Remove duplicates based on ISBN or title+author combination
        var uniqueBooks = DeduplicateResults(allResults);

        var response = new SearchBooksResponse
        {
            Books = uniqueBooks.Select(MapToResponse).ToList(),
            TotalResults = uniqueBooks.Count
        };

        _logger.LogInformation("Returning {Count} unique results", response.TotalResults);
        return response;
    }

    /// <summary>
    /// Clean and normalize OCR text for better search results
    /// </summary>
    private string CleanExtractedText(string text)
    {
        _logger.LogInformation("Original OCR text: {Text}", text);
        
        // Split into words
        var words = text.Split(new[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries);
        
        // Common publisher/edition words to filter out
        var stopWords = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "edición", "edition", "editorial", "editora", "press", "publishing",
            "publisher", "books", "library", "de", "by", "the", "a", "an", "del"
        };
        
        // Take meaningful words (typically title and author are first/longest)
        var meaningfulWords = words
            .Where(w => w.Length > 2 && !stopWords.Contains(w))
            .Take(8) // Take first 8 meaningful words
            .ToList();
        
        var cleanText = string.Join(" ", meaningfulWords);
        
        _logger.LogInformation("Cleaned search text: {CleanText}", cleanText);
        return cleanText;
    }

    /// <summary>
    /// Remove duplicate books from results based on ISBN or title+author
    /// </summary>
    private List<Book> DeduplicateResults(List<Book> books)
    {
        var seen = new HashSet<string>();
        var unique = new List<Book>();

        foreach (var book in books)
        {
            // Create a unique key based on ISBN or title+author
            var key = !string.IsNullOrEmpty(book.Isbn)
                ? book.Isbn
                : $"{book.Title}|{string.Join(",", book.Authors)}";

            if (seen.Add(key.ToLowerInvariant()))
            {
                unique.Add(book);
            }
        }

        return unique;
    }

    private static BookResponse MapToResponse(Book book)
    {
        return new BookResponse
        {
            Id = book.Id,
            Isbn = book.Isbn,
            Title = book.Title,
            Authors = book.Authors,
            Publisher = book.Publisher,
            PublishYear = book.PublishYear,
            CoverImageUrl = book.CoverImageUrl,
            Description = book.Description,
            PageCount = book.PageCount,
            Source = book.Source
        };
    }
}
