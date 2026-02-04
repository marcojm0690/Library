using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Domain;
using VirtualLibrary.Api.Infrastructure;
using VirtualLibrary.Api.Infrastructure.Cache;
using VirtualLibrary.Api.Infrastructure.External;
using System.Security.Claims;

namespace VirtualLibrary.Api.Controllers;

/// <summary>
/// Controller for library management operations
/// </summary>
[Authorize]
[ApiController]
[Route("api/[controller]")]
public class LibrariesController : ControllerBase
{
    private readonly ILibraryRepository _libraryRepository;
    private readonly IBookRepository _bookRepository;
    private readonly RedisCacheService _cache;
    private readonly GoogleBooksProvider _googleBooksProvider;
    private readonly OpenLibraryProvider _openLibraryProvider;
    private readonly ITranslatorService _translatorService;
    private readonly ILogger<LibrariesController> _logger;

    public LibrariesController(
        ILibraryRepository libraryRepository,
        IBookRepository bookRepository,
        RedisCacheService cache,
        GoogleBooksProvider googleBooksProvider,
        OpenLibraryProvider openLibraryProvider,
        ITranslatorService translatorService,
        ILogger<LibrariesController> logger)
    {
        _libraryRepository = libraryRepository;
        _bookRepository = bookRepository;
        _cache = cache;
        _googleBooksProvider = googleBooksProvider;
        _openLibraryProvider = openLibraryProvider;
        _translatorService = translatorService;
        _logger = logger;
    }

    private Guid GetAuthenticatedUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            throw new UnauthorizedAccessException("User ID not found in token");
        }
        return userId;
    }

    /// <summary>
    /// Get all libraries for the authenticated user
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<LibraryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<LibraryResponse>>> GetAll()
    {
        var userId = GetAuthenticatedUserId();
        var libraries = await _libraryRepository.GetByUserIdAsync(userId);
        var responses = libraries.Select(MapToResponse);
        return Ok(responses);
    }

    /// <summary>
    /// Get a library by ID (must belong to authenticated user)
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> GetById(Guid id)
    {
        var userId = GetAuthenticatedUserId();
        var cacheKey = $"library:{id}";
        
        // Check cache first
        var cachedLibrary = await _cache.GetAsync<Library>(cacheKey);
        if (cachedLibrary != null && cachedLibrary.UserId == userId)
        {
            _logger.LogInformation("Cache hit for library {LibraryId}", id);
            return Ok(MapToResponse(cachedLibrary));
        }
        
        _logger.LogInformation("Cache miss for library {LibraryId}", id);
        var library = await _libraryRepository.GetByIdAsync(id);
        
        if (library == null || library.UserId != userId)
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
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<LibraryResponse>>> GetByOwner(string owner)
    {
        try
        {
            _logger.LogInformation("🔵 GetByOwner called for owner: {Owner}", owner);
            
            var cacheKey = $"libraries:owner:{owner}";
            
            // Check cache first
            _logger.LogDebug("Checking cache for key: {CacheKey}", cacheKey);
            var cachedLibraries = await _cache.GetAsync<List<Library>>(cacheKey);
            if (cachedLibraries != null)
            {
                _logger.LogInformation("✅ Cache hit for owner {Owner} libraries (count: {Count})", owner, cachedLibraries.Count);
                var cachedResponses = cachedLibraries.Select(MapToResponse);
                return Ok(cachedResponses);
            }
            
            _logger.LogInformation("Cache miss for owner {Owner} libraries - querying database", owner);
            var libraries = await _libraryRepository.GetByOwnerAsync(owner);
            var libraryList = libraries.ToList();
            _logger.LogInformation("✅ Retrieved {Count} libraries from database for owner {Owner}", libraryList.Count, owner);
            
            // Cache for 3 minutes (shorter since this might change more frequently)
            await _cache.SetAsync(cacheKey, libraryList, TimeSpan.FromMinutes(3));
            _logger.LogDebug("Cached libraries for owner {Owner}", owner);
            
            var responses = libraryList.Select(MapToResponse);
            return Ok(responses);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error getting libraries for owner {Owner}: {Message}", owner, ex.Message);
            return StatusCode(500, new { error = "Failed to retrieve libraries", message = ex.Message });
        }
    }

    /// <summary>
    /// Create a new library for authenticated user
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LibraryResponse>> Create([FromBody] CreateLibraryRequest request)
    {
        var userId = GetAuthenticatedUserId();
        _logger.LogInformation("🔵 Create library endpoint called for user {UserId}", userId);
        _logger.LogInformation("🔵 Request: Name={Name}, Tags={Tags}, IsPublic={IsPublic}", 
            request.Name, request.Tags?.Count ?? 0, request.IsPublic);
        
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            _logger.LogWarning("❌ Library name is empty");
            return BadRequest(new { message = "Library name is required" });
        }

        var library = new Library
        {
            Name = request.Name,
            Description = request.Description,
            UserId = userId,
            Owner = User.FindFirst(ClaimTypes.Email)?.Value ?? "",
            Tags = request.Tags ?? new List<string>(),
            IsPublic = request.IsPublic,
            Type = request.Type
        };

        _logger.LogInformation("🔵 Creating library in database...");
        var created = await _libraryRepository.CreateAsync(library);
        _logger.LogInformation("✅ Library created with ID: {LibraryId}", created.Id);
        
        // Invalidate user cache
        var userCacheKey = $"libraries:user:{userId}";
        await _cache.RemoveAsync(userCacheKey);
        _logger.LogInformation("🔵 Invalidated cache for user: {UserId}", userId);
        
        var response = MapToResponse(created);

        return CreatedAtAction(nameof(GetById), new { id = created.Id }, response);
    }

    /// <summary>
    /// Update a library (must belong to authenticated user)
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> Update(Guid id, [FromBody] UpdateLibraryRequest request)
    {
        var userId = GetAuthenticatedUserId();
        var existing = await _libraryRepository.GetByIdAsync(id);
        
        if (existing == null || existing.UserId != userId)
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
        await InvalidateLibraryCache(id, updated.UserId);

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Delete a library (must belong to authenticated user)
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Delete(Guid id)
    {
        var userId = GetAuthenticatedUserId();
        // Get library first to check ownership and invalidate cache
        var library = await _libraryRepository.GetByIdAsync(id);
        
        if (library == null || library.UserId != userId)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }
        
        var deleted = await _libraryRepository.DeleteAsync(id);
        
        if (!deleted)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches
        await InvalidateLibraryCache(id, library.UserId);

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
        await InvalidateLibraryCache(id, updated.UserId);

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
        await InvalidateLibraryCache(id, updated.UserId);

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Get vocabulary hints for speech recognition based on user's libraries
    /// Returns authors, titles, and common book-related terms to improve transcription accuracy
    /// Enriched with subjects and categories from Google Books and Open Library
    /// </summary>
    [HttpGet("owner/{owner}/vocabulary-hints")]
    [ProducesResponseType(typeof(VocabularyHintsResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<VocabularyHintsResponse>> GetVocabularyHints(
        string owner, 
        [FromQuery] bool booksOnly = false)
    {
        _logger.LogInformation("Fetching vocabulary hints for owner {Owner} (booksOnly: {BooksOnly})", owner, booksOnly);
        
        var cacheKey = booksOnly 
            ? $"vocabulary:owner:{owner}:booksonly" 
            : $"vocabulary:owner:{owner}";
        
        // Check cache first (longer TTL since library content doesn't change that often)
        var cachedHints = await _cache.GetAsync<VocabularyHintsResponse>(cacheKey);
        if (cachedHints != null)
        {
            _logger.LogInformation("Cache hit for vocabulary hints for owner {Owner}", owner);
            return Ok(cachedHints);
        }
        
        // Get user's libraries
        var libraries = await _libraryRepository.GetByOwnerAsync(owner);
        var libraryList = libraries.ToList();
        
        var hints = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        
        // Get books from all user's libraries first
        var allBookIds = libraryList.SelectMany(l => l.BookIds).Distinct().ToList();
        var userBooks = new List<Book>();
        
        if (allBookIds.Any())
        {
            _logger.LogInformation("Fetching {BookCount} books from user's libraries", allBookIds.Count);
            
            foreach (var bookId in allBookIds)
            {
                var book = await _bookRepository.GetByIdAsync(bookId);
                if (book != null)
                {
                    userBooks.Add(book);
                }
            }
        }
        
        // Get tags - either user-defined or auto-generated from book content
        var tags = libraryList.SelectMany(l => l.Tags).Distinct().ToList();
        
        _logger.LogInformation("Found {LibraryCount} libraries with {TagCount} total tags", 
            libraryList.Count, tags.Count);
        
        if (tags.Any())
        {
            _logger.LogInformation("Using library tags: {Tags}", string.Join(", ", tags.Take(10)));
        }
        
        if (!tags.Any() && userBooks.Any())
        {
            _logger.LogInformation("No library tags found, auto-generating tags from {BookCount} books", userBooks.Count);
            tags = await GenerateTagsFromBooks(userBooks);
            _logger.LogInformation("Auto-generated {TagCount} tags: {Tags}", tags.Count, string.Join(", ", tags));
        }
        
        if (tags.Any() && !booksOnly)
        {
            _logger.LogInformation("Adding {TagCount} tags as vocabulary hints", tags.Count);
            
            // Add tags themselves as hints
            foreach (var tag in tags)
            {
                hints.Add(tag);
            }
            
            // Enrich with genre-related terms from external APIs
            _logger.LogInformation("Enriching vocabulary from {TagCount} tags using external APIs", tags.Count);
            await EnrichVocabularyFromTags(tags, hints, booksOnly);
        }
        
        // Add vocabulary from user's books
        foreach (var book in userBooks)
        {
            // Add all authors
            foreach (var author in book.Authors)
            {
                if (!string.IsNullOrWhiteSpace(author))
                {
                    hints.Add(author);
                    
                    // Also add individual name parts for better recognition
                    var nameParts = author.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                    foreach (var part in nameParts)
                    {
                        if (part.Length > 2) // Skip very short parts
                        {
                            hints.Add(part);
                        }
                    }
                }
            }
            
            // Add title
            if (!string.IsNullOrWhiteSpace(book.Title))
            {
                hints.Add(book.Title);
            }
            
            if (!booksOnly)
            {
                // Add publisher if available
                if (!string.IsNullOrWhiteSpace(book.Publisher))
                {
                    hints.Add(book.Publisher);
                }
                
                // Enrich with related terms from external APIs based on ISBN
                if (!string.IsNullOrWhiteSpace(book.Isbn))
                {
                    await EnrichVocabularyFromBook(book.Isbn, hints);
                }
            }
        }
        
        // If no personalized vocabulary, add common literary terms
        if (!hints.Any())
        {
            _logger.LogInformation("No library data found, using general book vocabulary");
            hints.UnionWith(GetGeneralBookVocabulary());
        }
        
        // Phonetic variations handled client-side by iOS Speech framework
        // Apple's SFCustomLanguageModelData provides superior ML-based recognition
        
        // Clean up hints - remove fragments, special characters, and very short terms
        var cleanedHints = hints
            .Where(h => h.Length > 2) // At least 3 characters
            .Where(h => !h.Contains("(") && !h.Contains(")")) // No partial fragments like "(Madrid)"
            .Where(h => !h.EndsWith(",")) // No trailing punctuation
            .Where(h => !h.EndsWith(":"))
            .Where(h => char.IsLetter(h[0])) // Starts with a letter
            .ToList();

        var response = new VocabularyHintsResponse
        {
            Hints = cleanedHints.OrderBy(h => h).ToList(),
            Tags = tags,
            BookCount = userBooks.Count,
            IsPersonalized = userBooks.Any()
        };
        
        // Cache for 10 minutes
        await _cache.SetAsync(cacheKey, response, TimeSpan.FromMinutes(10));
        
        _logger.LogInformation("Returning {HintCount} vocabulary hints for owner {Owner}", response.Hints.Count, owner);
        
        return Ok(response);
    }
        
    /// <summary>
    /// Auto-generate tags from book collection based on common themes, publishers, and time periods
    /// </summary>
    private async Task<List<string>> GenerateTagsFromBooks(List<Book> books)
    {
        var generatedTags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        
        // Analyze publishers to identify common publishing houses
        var publisherGroups = books
            .Where(b => !string.IsNullOrWhiteSpace(b.Publisher))
            .GroupBy(b => b.Publisher)
            .Where(g => g.Count() >= 2) // At least 2 books from same publisher
            .OrderByDescending(g => g.Count())
            .Take(3);
        
        foreach (var group in publisherGroups)
        {
            // Add publisher as tag (e.g., "Penguin Classics", "Oxford University Press")
            if (group.Key!.Contains("Classic", StringComparison.OrdinalIgnoreCase))
            {
                generatedTags.Add("classics");
            }
            
            if (group.Key.Contains("University", StringComparison.OrdinalIgnoreCase))
            {
                generatedTags.Add("academic");
            }
        }
        
        // Analyze publication years to identify time period focus
        var yearsWithBooks = books
            .Where(b => b.PublishYear.HasValue && b.PublishYear > 1800)
            .Select(b => b.PublishYear!.Value)
            .ToList();
        
        if (yearsWithBooks.Any())
        {
            var avgYear = yearsWithBooks.Average();
            
            if (avgYear < 1950)
            {
                generatedTags.Add("classic literature");
            }
            else if (avgYear > 2010)
            {
                generatedTags.Add("contemporary");
            }
        }
        
        // Search for common subjects/genres by sampling books with ISBNs
        var booksWithIsbn = books.Where(b => !string.IsNullOrWhiteSpace(b.Isbn)).Take(5).ToList();
        
        foreach (var book in booksWithIsbn)
        {
            try
            {
                // Try to get more detailed metadata from Google Books
                var enrichedBook = await _googleBooksProvider.SearchByIsbnAsync(book.Isbn!);
                
                // Google Books might return subjects/categories in description
                // For now, we'll analyze the title and publisher for genre hints
                if (!string.IsNullOrWhiteSpace(book.Description))
                {
                    var descriptionLower = book.Description.ToLower();
                    
                    // Philosophy
                    if (descriptionLower.Contains("philosophy") || descriptionLower.Contains("philosophical"))
                        generatedTags.Add("philosophy");
                    
                    // Science
                    if (descriptionLower.Contains("science") || descriptionLower.Contains("scientific"))
                        generatedTags.Add("science");
                    
                    // History
                    if (descriptionLower.Contains("history") || descriptionLower.Contains("historical"))
                        generatedTags.Add("history");
                    
                    // Fiction genres
                    if (descriptionLower.Contains("fantasy"))
                        generatedTags.Add("fantasy");
                    
                    if (descriptionLower.Contains("science fiction") || descriptionLower.Contains("sci-fi"))
                        generatedTags.Add("science fiction");
                    
                    if (descriptionLower.Contains("mystery") || descriptionLower.Contains("detective"))
                        generatedTags.Add("mystery");
                    
                    if (descriptionLower.Contains("romance"))
                        generatedTags.Add("romance");
                    
                    if (descriptionLower.Contains("thriller"))
                        generatedTags.Add("thriller");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to enrich book for tag generation: {Isbn}", book.Isbn);
            }
        }
        
        // Analyze author patterns to identify genre focus
        var authorCounts = books
            .SelectMany(b => b.Authors)
            .Where(a => !string.IsNullOrWhiteSpace(a))
            .GroupBy(a => a, StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Count() >= 2) // Author appears at least twice
            .Select(g => g.Key)
            .ToList();
        
        // If user has multiple books from same authors, might indicate genre preference
        if (authorCounts.Count >= 3)
        {
            generatedTags.Add("curated collection");
        }
        
        // Analyze titles for common keywords
        var allTitles = string.Join(" ", books.Select(b => b.Title)).ToLower();
        
        if (allTitles.Contains("introduction") || allTitles.Contains("guide"))
            generatedTags.Add("educational");
        
        if (allTitles.Contains("complete") || allTitles.Contains("collected"))
            generatedTags.Add("complete works");
        
        // Ensure we have at least some tags
        if (!generatedTags.Any())
        {
            generatedTags.Add("general collection");
        }
        
        return generatedTags.Take(5).ToList(); // Limit to 5 auto-generated tags
    }
    
    /// <summary>
    /// Enrich vocabulary with subjects and categories from external APIs based on tags
    /// </summary>
    private async Task EnrichVocabularyFromTags(List<string> tags, HashSet<string> hints, bool booksOnly = false)
    {
        try
        {
            // Search for books in each tag category to get related terms
            foreach (var originalTag in tags.Take(5)) // Process up to 5 tags
            {
                // Translate tag to English for better API search results
                var searchTag = await _translatorService.TranslateToEnglishAsync(originalTag);
                
                if (searchTag != originalTag)
                {
                    _logger.LogInformation("Translated tag '{OriginalTag}' to '{TranslatedTag}' for API search", 
                        originalTag, searchTag);
                }
                else
                {
                    _logger.LogInformation("Using original tag '{Tag}' for API search", originalTag);
                }
                
                // Search Google Books for this tag/genre
                var googleBooks = await _googleBooksProvider.SearchByTextAsync(searchTag);
                
                foreach (var book in googleBooks.Take(10)) // Take first 10 results for more vocabulary
                {
                    // Add authors from related books
                    foreach (var author in book.Authors)
                    {
                        if (!string.IsNullOrWhiteSpace(author) && author.Length > 3)
                        {
                            hints.Add(author);
                            
                            // Add individual name parts
                            var nameParts = author.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                            foreach (var part in nameParts)
                            {
                                if (part.Length > 2)
                                {
                                    hints.Add(part);
                                }
                            }
                        }
                    }
                    
                    // Add book titles from the genre
                    if (!string.IsNullOrWhiteSpace(book.Title))
                    {
                        hints.Add(book.Title);
                    }
                    
                    if (!booksOnly)
                    {
                        // Add significant words from titles (filter out common words)
                        var titleWords = book.Title?
                            .Split(new[] { ' ', ':', '-', '—' }, StringSplitOptions.RemoveEmptyEntries)
                            .Where(w => w.Length > 4 && !IsCommonWord(w));
                        
                        if (titleWords != null)
                        {
                            foreach (var word in titleWords)
                            {
                                hints.Add(word);
                            }
                        }
                        
                        // Add publishers for genre context
                        if (!string.IsNullOrWhiteSpace(book.Publisher))
                        {
                            hints.Add(book.Publisher);
                        }
                        
                        // Extract genre-related terms from descriptions
                        if (!string.IsNullOrWhiteSpace(book.Description))
                        {
                            ExtractKeywordsFromDescription(book.Description, hints);
                        }
                    }
                }
                
                // Also search Open Library for the tag
                var openLibraryBooks = await _openLibraryProvider.SearchByTextAsync(searchTag);
                
                foreach (var book in openLibraryBooks.Take(10))
                {
                    // Add authors
                    foreach (var author in book.Authors)
                    {
                        if (!string.IsNullOrWhiteSpace(author) && author.Length > 3)
                        {
                            hints.Add(author);
                        }
                    }
                    
                    // Add titles
                    if (!string.IsNullOrWhiteSpace(book.Title))
                    {
                        hints.Add(book.Title);
                    }
                }
                
                _logger.LogInformation("Added vocabulary from {GoogleCount} Google Books and {OpenLibraryCount} Open Library books for tag '{Tag}'", 
                    googleBooks.Count, openLibraryBooks.Count, searchTag);
                
                // Add domain-specific vocabulary for certain tags (always add famous authors)
                AddDomainSpecificVocabulary(searchTag, hints);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to enrich vocabulary from tags");
            // Continue without enrichment - not critical
        }
    }
    
    /// <summary>
    /// Add well-known authors and works for specific academic domains
    /// </summary>
    private void AddDomainSpecificVocabulary(string tag, HashSet<string> hints)
    {
        var tagLower = tag.ToLower();
        
        // Philosophy and Ethics - canonical philosophers
        if (tagLower.Contains("philos") || tagLower.Contains("ethic"))
        {
            var philosophers = new[]
            {
                "Kant", "Immanuel Kant",
                "Aristotle",
                "Plato", "Socrates",
                "Nietzsche", "Friedrich Nietzsche",
                "Hegel", "Georg Hegel",
                "Descartes", "René Descartes",
                "Spinoza", "Baruch Spinoza",
                "Hume", "David Hume",
                "Locke", "John Locke",
                "Mill", "John Stuart Mill",
                "Kierkegaard", "Søren Kierkegaard",
                "Schopenhauer", "Arthur Schopenhauer",
                "Heidegger", "Martin Heidegger",
                "Sartre", "Jean-Paul Sartre",
                "Wittgenstein", "Ludwig Wittgenstein",
                "Aquinas", "Thomas Aquinas",
                "Rousseau", "Jean-Jacques Rousseau",
                "Hobbes", "Thomas Hobbes",
                "Marx", "Karl Marx",
                "Foucault", "Michel Foucault",
                "Derrida", "Jacques Derrida"
            };
            
            foreach (var philosopher in philosophers)
            {
                hints.Add(philosopher);
            }
            
            _logger.LogInformation("Added {Count} philosophy-specific vocabulary terms", philosophers.Length);
        }
        
        // Add more domains as needed (science, history, etc.)
    }
    
    /// <summary>
    /// Extract important keywords from book descriptions for vocabulary hints
    /// </summary>
    private void ExtractKeywordsFromDescription(string description, HashSet<string> hints)
    {
        var descriptionLower = description.ToLower();
        
        // Genre keywords
        var genreKeywords = new[]
        {
            "philosophy", "philosophical", "existential", "metaphysical",
            "science", "scientific", "biology", "physics", "chemistry",
            "history", "historical", "medieval", "ancient", "modern",
            "fantasy", "magical", "wizard", "dragon", "epic",
            "science fiction", "sci-fi", "cyberpunk", "dystopian", "space",
            "mystery", "detective", "thriller", "suspense", "crime",
            "romance", "love", "relationship",
            "adventure", "journey", "quest",
            "biography", "memoir", "autobiography",
            "poetry", "poem", "verse",
            "classic", "literature", "literary"
        };
        
        foreach (var keyword in genreKeywords)
        {
            if (descriptionLower.Contains(keyword))
            {
                hints.Add(keyword);
            }
        }
        
        // Extract capitalized proper nouns (likely important names/places)
        var words = description.Split(new[] { ' ', '.', ',', ';', ':', '!', '?' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var word in words)
        {
            // Look for capitalized words that aren't at start of sentences
            if (word.Length > 4 && 
                char.IsUpper(word[0]) && 
                word.Skip(1).Any(char.IsLower) &&
                !IsCommonWord(word))
            {
                hints.Add(word);
            }
        }
    }
    
    /// <summary>
    /// Check if a word is a common word that shouldn't be used as a hint
    /// </summary>
    private bool IsCommonWord(string word)
    {
        var commonWords = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "the", "and", "for", "with", "from", "that", "this", "these", "those",
            "about", "after", "before", "when", "where", "which", "while",
            "book", "books", "novel", "story", "tales", "volume", "edition"
        };
        
        return commonWords.Contains(word);
    }
    
    /// <summary>
    /// Enrich vocabulary with subjects, categories, and related terms from external APIs
    /// </summary>
    private async Task EnrichVocabularyFromBook(string isbn, HashSet<string> hints)
    {
        try
        {
            // Try Google Books first
            var googleBook = await _googleBooksProvider.SearchByIsbnAsync(isbn);
            
            if (googleBook != null)
            {
                // Google Books doesn't expose categories in our current implementation
                // but we can get publisher and other metadata
                _logger.LogInformation("Enriched from Google Books for ISBN {Isbn}", isbn);
            }
            
            // Try Open Library for additional metadata
            var openLibraryBook = await _openLibraryProvider.SearchByIsbnAsync(isbn);
            
            if (openLibraryBook != null)
            {
                // Open Library might have subjects/categories we can use
                _logger.LogInformation("Enriched from Open Library for ISBN {Isbn}", isbn);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to enrich vocabulary for ISBN {Isbn}", isbn);
            // Continue without enrichment - not critical
        }
    }
    
    /// <summary>
    /// Get general book-related vocabulary for users without personalized libraries
    /// </summary>
    private static List<string> GetGeneralBookVocabulary() => new()
    {
        // Common search terms
        "book", "books", "author", "title", "fiction", "nonfiction", "novel",
        "by", "written", "published", "publisher", "edition",
        
        // Genres
        "fantasy", "science fiction", "mystery", "thriller", "romance",
        "biography", "autobiography", "history", "philosophy", "poetry",
        "drama", "comedy", "horror", "adventure", "classic",
        
        // Common classic authors (to help with pronunciation)
        "Shakespeare", "Austen", "Dickens", "Tolstoy", "Dostoevsky",
        "Hemingway", "Fitzgerald", "Orwell", "Kafka", "Kant",
        "Nietzsche", "Plato", "Aristotle", "Homer", "Dante",
        "Cervantes", "Joyce", "Proust", "Woolf", "Faulkner"
    };
    
    /// <summary>
    /// Invalidate library cache when data changes
    /// </summary>
    private async Task InvalidateLibraryCache(Guid libraryId, Guid userId)
    {
        // Remove individual library cache
        await _cache.RemoveAsync($"library:{libraryId}");
        
        // Remove user's libraries cache
        await _cache.RemoveAsync($"libraries:user:{userId}");
        
        // Remove vocabulary cache since library content changed
        await _cache.RemoveAsync($"vocabulary:user:{userId}");
        
        _logger.LogInformation("Invalidated cache for library {LibraryId} and user {UserId}", libraryId, userId);
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
        IsPublic = library.IsPublic,
        Type = library.Type
    };
}
