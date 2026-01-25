using Microsoft.AspNetCore.Mvc;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Domain;
using VirtualLibrary.Api.Infrastructure.Cache;

namespace VirtualLibrary.Api.Controllers;

/// <summary>
/// Controller for library management operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class LibrariesController : ControllerBase
{
    private readonly ILibraryRepository _libraryRepository;
    private readonly IBookRepository _bookRepository;
    private readonly RedisCacheService _cache;
    private readonly ILogger<LibrariesController> _logger;

    public LibrariesController(
        ILibraryRepository libraryRepository,
        IBookRepository bookRepository,
        RedisCacheService cache,
        ILogger<LibrariesController> logger)
    {
        _libraryRepository = libraryRepository;
        _bookRepository = bookRepository;
        _cache = cache;
        _logger = logger;
    }

    /// <summary>
    /// Get all libraries
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<LibraryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<LibraryResponse>>> GetAll()
    {
        var libraries = await _libraryRepository.GetAllAsync();
        var responses = libraries.Select(MapToResponse);
        return Ok(responses);
    }

    /// <summary>
    /// Get a library by ID
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> GetById(Guid id)
    {
        var cacheKey = $"library:{id}";
        
        // Check cache first
        var cachedLibrary = await _cache.GetAsync<Library>(cacheKey);
        if (cachedLibrary != null)
        {
            _logger.LogInformation("Cache hit for library {LibraryId}", id);
            return Ok(MapToResponse(cachedLibrary));
        }
        
        _logger.LogInformation("Cache miss for library {LibraryId}", id);
        var library = await _libraryRepository.GetByIdAsync(id);
        
        if (library == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Cache for 5 minutes
        await _cache.SetAsync(cacheKey, library, TimeSpan.FromMinutes(5));
        
        return Ok(MapToResponse(library));
    }

    /// <summary>
    /// Get libraries by owner
    /// </summary>
    [HttpGet("owner/{owner}")]
    [ProducesResponseType(typeof(IEnumerable<LibraryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<LibraryResponse>>> GetByOwner(string owner)
    {
        var cacheKey = $"libraries:owner:{owner}";
        
        // Check cache first
        var cachedLibraries = await _cache.GetAsync<List<Library>>(cacheKey);
        if (cachedLibraries != null)
        {
            _logger.LogInformation("Cache hit for owner {Owner} libraries", owner);
            var cachedResponses = cachedLibraries.Select(MapToResponse);
            return Ok(cachedResponses);
        }
        
        _logger.LogInformation("Cache miss for owner {Owner} libraries", owner);
        var libraries = await _libraryRepository.GetByOwnerAsync(owner);
        var libraryList = libraries.ToList();
        
        // Cache for 3 minutes (shorter since this might change more frequently)
        await _cache.SetAsync(cacheKey, libraryList, TimeSpan.FromMinutes(3));
        
        var responses = libraryList.Select(MapToResponse);
        return Ok(responses);
    }

    /// <summary>
    /// Create a new library
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LibraryResponse>> Create([FromBody] CreateLibraryRequest request)
    {
        _logger.LogInformation("🔵 Create library endpoint called");
        _logger.LogInformation("🔵 Request: Name={Name}, Owner={Owner}, Tags={Tags}, IsPublic={IsPublic}", 
            request.Name, request.Owner, request.Tags?.Count ?? 0, request.IsPublic);
        
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            _logger.LogWarning("❌ Library name is empty");
            return BadRequest(new { message = "Library name is required" });
        }

        if (string.IsNullOrWhiteSpace(request.Owner))
        {
            _logger.LogWarning("❌ Owner is empty");
            return BadRequest(new { message = "Owner is required" });
        }

        var library = new Library
        {
            Name = request.Name,
            Description = request.Description,
            Owner = request.Owner,
            Tags = request.Tags ?? new List<string>(),
            IsPublic = request.IsPublic
        };

        _logger.LogInformation("🔵 Creating library in database...");
        var created = await _libraryRepository.CreateAsync(library);
        _logger.LogInformation("✅ Library created with ID: {LibraryId}", created.Id);
        
        // Invalidate owner cache
        var ownerCacheKey = $"libraries:owner:{request.Owner}";
        await _cache.RemoveAsync(ownerCacheKey);
        _logger.LogInformation("🔵 Invalidated cache for owner: {Owner}", request.Owner);
        
        var response = MapToResponse(created);

        return CreatedAtAction(nameof(GetById), new { id = created.Id }, response);
    }

    /// <summary>
    /// Update a library
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> Update(Guid id, [FromBody] UpdateLibraryRequest request)
    {
        var existing = await _libraryRepository.GetByIdAsync(id);
        
        if (existing == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Update only provided fields
        if (request.Name != null) existing.Name = request.Name;
        if (request.Description != null) existing.Description = request.Description;
        if (request.Tags != null) existing.Tags = request.Tags;
        if (request.IsPublic.HasValue) existing.IsPublic = request.IsPublic.Value;

        var updated = await _libraryRepository.UpdateAsync(existing);
        
        if (updated == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches
        await InvalidateLibraryCache(id, updated.Owner);

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Delete a library
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Delete(Guid id)
    {
        // Get library first to invalidate owner cache
        var library = await _libraryRepository.GetByIdAsync(id);
        
        var deleted = await _libraryRepository.DeleteAsync(id);
        
        if (!deleted)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches
        if (library != null)
        {
            await InvalidateLibraryCache(id, library.Owner);
        }

        return NoContent();
    }

    /// <summary>
    /// Add books to a library (ensures books exist in database first)
    /// </summary>
    [HttpPost("{id:guid}/books")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> AddBooks(Guid id, [FromBody] AddBooksToLibraryRequest request)
    {
        _logger.LogInformation("Adding {Count} books to library {LibraryId}", request.BookIds.Count, id);
        
        // Ensure all books exist in the database
        var validBookIds = new List<Guid>();
        foreach (var bookId in request.BookIds)
        {
            var book = await _bookRepository.GetByIdAsync(bookId);
            if (book != null)
            {
                validBookIds.Add(bookId);
                _logger.LogInformation("Book {BookId} exists: {Title}", bookId, book.Title);
            }
            else
            {
                _logger.LogWarning("Book {BookId} not found in database - skipping", bookId);
            }
        }
        
        if (validBookIds.Count == 0)
        {
            _logger.LogWarning("No valid books found to add to library {LibraryId}", id);
            return BadRequest(new { message = "None of the provided book IDs exist in the database" });
        }
        
        var updated = await _libraryRepository.AddBooksAsync(id, validBookIds);
        
        if (updated == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches since book count changed
        await InvalidateLibraryCache(id, updated.Owner);

        _logger.LogInformation("Successfully added {Count} books to library {LibraryId}", validBookIds.Count, id);
        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Get books in a library with enriched data from external APIs
    /// </summary>
    [HttpGet("{id:guid}/books")]
    [ProducesResponseType(typeof(IEnumerable<BookResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IEnumerable<BookResponse>>> GetLibraryBooks(
        Guid id, 
        [FromServices] IBookRepository bookRepository,
        [FromServices] IEnumerable<IBookProvider> bookProviders)
    {
        var library = await _libraryRepository.GetByIdAsync(id);
        
        if (library == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        _logger.LogInformation("Fetching {Count} books for library {LibraryId}", library.BookIds.Count, id);

        var books = new List<BookResponse>();
        foreach (var bookId in library.BookIds)
        {
            _logger.LogInformation("Looking for book {BookId}", bookId);
            var book = await bookRepository.GetByIdAsync(bookId);
            if (book != null)
            {
                _logger.LogInformation("Found book: {Title}", book.Title);
                // Try to enrich book data from external APIs if missing critical info
                var enrichedBook = await EnrichBookDataAsync(book, bookProviders);
                
                books.Add(new BookResponse
                {
                    Id = enrichedBook.Id,
                    Title = enrichedBook.Title,
                    Authors = enrichedBook.Authors,
                    Description = enrichedBook.Description,
                    Isbn = enrichedBook.Isbn,
                    Publisher = enrichedBook.Publisher,
                    PublishYear = enrichedBook.PublishYear,
                    PageCount = enrichedBook.PageCount,
                    CoverImageUrl = enrichedBook.CoverImageUrl,
                    Source = enrichedBook.Source
                });
            }
            else
            {
                _logger.LogWarning("Book {BookId} not found in repository", bookId);
            }
        }

        _logger.LogInformation("Returning {Count} books for library {LibraryId}", books.Count, id);
        return Ok(books);
    }

    /// <summary>
    /// Enriches book data by fetching from external APIs if data is missing
    /// Priority: ISBNdb > Wikidata > Google Books > Open Library (for cover images)
    /// </summary>
    private async Task<Book> EnrichBookDataAsync(Book book, IEnumerable<IBookProvider> bookProviders)
    {
        // If book already has complete data (cover, description, ISBN, etc.), return as-is
        if (!string.IsNullOrEmpty(book.CoverImageUrl) && 
            !string.IsNullOrEmpty(book.Description) &&
            !string.IsNullOrEmpty(book.Isbn) &&
            book.PageCount.HasValue)
        {
            return book;
        }

        // If we have an ISBN, try to fetch complete data
        if (!string.IsNullOrEmpty(book.Isbn))
        {
            _logger.LogInformation("Enriching book data for: {Title} (ISBN: {Isbn})", book.Title, book.Isbn);
            
            // Try each provider in order until we get a cover image
            foreach (var provider in bookProviders)
            {
                try
                {
                    var enrichedBook = await provider.SearchByIsbnAsync(book.Isbn);
                    if (enrichedBook != null)
                    {
                        // Prioritize cover images - only fill if we don't have one yet
                        if (string.IsNullOrEmpty(book.CoverImageUrl) && !string.IsNullOrEmpty(enrichedBook.CoverImageUrl))
                        {
                            book.CoverImageUrl = enrichedBook.CoverImageUrl;
                            _logger.LogInformation("Got cover image from {Provider}", provider.ProviderName);
                        }
                        
                        // Merge other data - keep existing data, only fill in missing fields
                        book.Description ??= enrichedBook.Description;
                        book.Publisher ??= enrichedBook.Publisher;
                        book.PublishYear ??= enrichedBook.PublishYear;
                        book.PageCount ??= enrichedBook.PageCount;
                        book.ExternalId ??= enrichedBook.ExternalId;
                        book.Source ??= enrichedBook.Source;
                        
                        if (book.Authors.Count == 0 && enrichedBook.Authors.Count > 0)
                        {
                            book.Authors = enrichedBook.Authors;
                        }
                        
                        _logger.LogInformation("Successfully enriched book data from {Provider}", provider.ProviderName);
                        
                        // Update the book in the database with enriched data
                        await _bookRepository.UpdateAsync(book);
                        
                        // If we have cover image now, we can stop (other data is less critical)
                        if (!string.IsNullOrEmpty(book.CoverImageUrl))
                        {
                            break;
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to enrich book data from {Provider}", provider.ProviderName);
                }
            }
        }
        else
        {
            // No ISBN - try to find it by searching for title + author
            _logger.LogInformation("Book has no ISBN, searching by title: {Title}", book.Title);
            
            var searchText = book.Title;
            if (book.Authors.Count > 0)
            {
                searchText += " " + book.Authors[0];
            }
            
            foreach (var provider in bookProviders)
            {
                try
                {
                    var searchResults = await provider.SearchByTextAsync(searchText);
                    if (searchResults != null && searchResults.Count > 0)
                    {
                        // Take the first result that has an ISBN
                        var enrichedBook = searchResults.FirstOrDefault(b => !string.IsNullOrEmpty(b.Isbn));
                        if (enrichedBook != null)
                        {
                            _logger.LogInformation("Found ISBN {Isbn} for book {Title} from {Provider}", 
                                enrichedBook.Isbn, book.Title, provider.ProviderName);
                            
                            // Merge data from the found book
                            book.Isbn ??= enrichedBook.Isbn;
                            book.Description ??= enrichedBook.Description;
                            book.Publisher ??= enrichedBook.Publisher;
                            book.PublishYear ??= enrichedBook.PublishYear;
                            book.PageCount ??= enrichedBook.PageCount;
                            book.ExternalId ??= enrichedBook.ExternalId;
                            book.Source ??= enrichedBook.Source;
                            
                            if (string.IsNullOrEmpty(book.CoverImageUrl) && !string.IsNullOrEmpty(enrichedBook.CoverImageUrl))
                            {
                                book.CoverImageUrl = enrichedBook.CoverImageUrl;
                            }
                            
                            if (book.Authors.Count == 0 && enrichedBook.Authors.Count > 0)
                            {
                                book.Authors = enrichedBook.Authors;
                            }
                            
                            // Update the book in database with ISBN and other enriched data
                            await _bookRepository.UpdateAsync(book);
                            
                            break; // Found what we need, stop searching
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to search for book by text from {Provider}", provider.ProviderName);
                }
            }
        }

        return book;
    }

    /// <summary>
    /// Remove books from a library
    /// </summary>
    [HttpDelete("{id:guid}/books")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> RemoveBooks(Guid id, [FromBody] AddBooksToLibraryRequest request)
    {
        var updated = await _libraryRepository.RemoveBooksAsync(id, request.BookIds);
        
        if (updated == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches since book count changed
        await InvalidateLibraryCache(id, updated.Owner);

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Invalidate library cache when data changes
    /// </summary>
    private async Task InvalidateLibraryCache(Guid libraryId, string owner)
    {
        // Remove individual library cache
        await _cache.RemoveAsync($"library:{libraryId}");
        
        // Remove owner's libraries cache
        await _cache.RemoveAsync($"libraries:owner:{owner}");
        
        _logger.LogInformation("Invalidated cache for library {LibraryId} and owner {Owner}", libraryId, owner);
    }

    private static LibraryResponse MapToResponse(Library library) => new()
    {
        Id = library.Id,
        Name = library.Name,
        Description = library.Description,
        Owner = library.Owner,
        CreatedAt = library.CreatedAt,
        UpdatedAt = library.UpdatedAt,
        BookIds = library.BookIds,
        BookCount = library.BookIds.Count,
        Tags = library.Tags,
        IsPublic = library.IsPublic
    };
}
