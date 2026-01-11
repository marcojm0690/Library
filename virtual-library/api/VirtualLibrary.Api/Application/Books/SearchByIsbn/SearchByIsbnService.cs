using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Application.Books.SearchByIsbn;

/// <summary>
/// Service responsible for looking up books by ISBN.
/// Orchestrates searching across multiple external providers and local repository.
/// </summary>
public class SearchByIsbnService
{
    private readonly IEnumerable<IBookProvider> _bookProviders;
    private readonly IBookRepository _bookRepository;
    private readonly ILogger<SearchByIsbnService> _logger;

    public SearchByIsbnService(
        IEnumerable<IBookProvider> bookProviders,
        IBookRepository bookRepository,
        ILogger<SearchByIsbnService> logger)
    {
        _bookProviders = bookProviders;
        _bookRepository = bookRepository;
        _logger = logger;
    }

    /// <summary>
    /// Search for a book by ISBN. First checks local repository, then external providers.
    /// </summary>
    public async Task<BookResponse?> ExecuteAsync(string isbn, CancellationToken cancellationToken = default)
    {
        // Validate ISBN format
        if (string.IsNullOrWhiteSpace(isbn))
        {
            _logger.LogWarning("ISBN search called with empty ISBN");
            return null;
        }

        // Clean ISBN (remove dashes, spaces)
        var cleanIsbn = isbn.Replace("-", "").Replace(" ", "").Trim();

        // First, check if book exists in local repository
        var existingBook = await _bookRepository.GetByIsbnAsync(cleanIsbn, cancellationToken);
        if (existingBook != null)
        {
            _logger.LogInformation("Book found in local repository: {Isbn}", cleanIsbn);
            return MapToResponse(existingBook);
        }

        // If not found locally, search external providers
        foreach (var provider in _bookProviders)
        {
            try
            {
                _logger.LogInformation("Searching {Provider} for ISBN: {Isbn}", provider.ProviderName, cleanIsbn);
                var book = await provider.SearchByIsbnAsync(cleanIsbn, cancellationToken);
                
                if (book != null)
                {
                    _logger.LogInformation("Book found via {Provider}: {Title}", provider.ProviderName, book.Title);
                    
                    // Save to repository for future lookups
                    var savedBook = await _bookRepository.SaveAsync(book, cancellationToken);
                    return MapToResponse(savedBook);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error searching {Provider} for ISBN: {Isbn}", provider.ProviderName, cleanIsbn);
                // Continue to next provider
            }
        }

        _logger.LogWarning("Book not found for ISBN: {Isbn}", cleanIsbn);
        return null;
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
