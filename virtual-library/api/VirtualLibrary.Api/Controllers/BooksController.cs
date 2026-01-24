using Microsoft.AspNetCore.Mvc;
using VirtualLibrary.Api.Application.Books.SearchByIsbn;
using VirtualLibrary.Api.Application.Books.SearchByCover;
using VirtualLibrary.Api.Application.Books.SearchByImage;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Infrastructure.External;
using VirtualLibrary.Api.Infrastructure.Persistence;

namespace VirtualLibrary.Api.Controllers;

/// <summary>
/// API controller for book-related operations.
/// Provides endpoints for ISBN lookup, cover-based search, and image-based identification.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class BooksController : ControllerBase
{
    private readonly SearchByIsbnService _searchByIsbnService;
    private readonly SearchByCoverService _searchByCoverService;
    private readonly SearchByImageService _searchByImageService;
    private readonly AzureBlobLibraryRepository _libraryRepository;
    private readonly IBookRepository _bookRepository;
    private readonly ILogger<BooksController> _logger;

    public BooksController(
        SearchByIsbnService searchByIsbnService,
        SearchByCoverService searchByCoverService,
        SearchByImageService searchByImageService,
        AzureBlobLibraryRepository libraryRepository,
        IBookRepository bookRepository,
        ILogger<BooksController> logger)
    {
        _searchByIsbnService = searchByIsbnService;
        _searchByCoverService = searchByCoverService;
        _searchByImageService = searchByImageService;
        _libraryRepository = libraryRepository;
        _bookRepository = bookRepository;
        _logger = logger;
    }

    /// <summary>
    /// Look up a book by its ISBN (barcode scan result).
    /// </summary>
    /// <param name="request">Request containing ISBN to lookup</param>
    /// <returns>Book information if found, 404 if not found</returns>
    [HttpPost("lookup")]
    [ProducesResponseType(typeof(BookResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> LookupByIsbn([FromBody] LookupByIsbnRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Isbn))
        {
            return BadRequest(new { error = "ISBN is required" });
        }

        _logger.LogInformation("Lookup request for ISBN: {Isbn}", request.Isbn);

        var result = await _searchByIsbnService.ExecuteAsync(request.Isbn);

        if (result == null)
        {
            return NotFound(new { error = "Book not found", isbn = request.Isbn });
        }

        return Ok(result);
    }

    /// <summary>
    /// Get a book by its internal ID.
    /// </summary>
    /// <param name="id">The book's unique identifier</param>
    /// <returns>Book information if found, 404 if not found</returns>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(BookResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetById(Guid id)
    {
        try
        {
            _logger.LogInformation("Get book request for ID: {BookId}", id);

            var book = await _bookRepository.GetByIdAsync(id);

            if (book == null)
            {
                return NotFound(new { error = "Book not found", id });
            }

            var response = new BookResponse
            {
                Id = book.Id,
                Title = book.Title,
                Authors = book.Authors,
                Description = book.Description,
                Isbn = book.Isbn,
                Publisher = book.Publisher,
                PublishYear = book.PublishYear,
                PageCount = book.PageCount,
                CoverImageUrl = book.CoverImageUrl,
                Source = "Repository"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving book by ID: {BookId}", id);
            return StatusCode(500, new { error = "Error retrieving book", details = ex.Message });
        }
    }

    /// <summary>
    /// Get all books in the repository.
    /// </summary>
    /// <returns>List of all books</returns>
    [HttpGet]
    [ProducesResponseType(typeof(List<BookResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetAllBooks()
    {
        try
        {
            _logger.LogInformation("Retrieving all books");

            var books = await _bookRepository.GetAllAsync();

            var response = books.Select(book => new BookResponse
            {
                Id = book.Id,
                Title = book.Title,
                Authors = book.Authors,
                Description = book.Description,
                Isbn = book.Isbn,
                Publisher = book.Publisher,
                PublishYear = book.PublishYear,
                PageCount = book.PageCount,
                CoverImageUrl = book.CoverImageUrl,
                Source = "Repository"
            }).ToList();

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all books");
            return StatusCode(500, new { error = "Error retrieving books", details = ex.Message });
        }
    }

    /// <summary>
    /// Search for books based on text extracted from cover image (OCR).
    /// </summary>
    /// <param name="request">Request containing OCR-extracted text</param>
    /// <returns>List of potential book matches</returns>
    [HttpPost("search-by-cover")]
    [ProducesResponseType(typeof(SearchBooksResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SearchByCover([FromBody] SearchByCoverRequest request)
    {
        _logger.LogInformation("Cover search request - Text length: {TextLength}, Has image: {HasImage}", 
            request.ExtractedText?.Length ?? 0, 
            !string.IsNullOrWhiteSpace(request.ImageData));

        // If image is provided, try image-based search first (priority)
        if (!string.IsNullOrWhiteSpace(request.ImageData))
        {
            try
            {
                _logger.LogInformation("Attempting image-based book identification...");
                
                // Convert Base64 to stream
                var imageBytes = Convert.FromBase64String(request.ImageData);
                using var imageStream = new MemoryStream(imageBytes);

                var book = await _searchByImageService.IdentifyBookAsync(imageStream);

                if (book != null)
                {
                    _logger.LogInformation("✅ Book identified from image: {Title}", book.Title);
                    
                    // Return single book result
                    var response = new SearchBooksResponse
                    {
                        Books = new List<BookResponse>
                        {
                            new BookResponse
                            {
                                Id = book.Id,
                                Title = book.Title,
                                Authors = book.Authors,
                                Isbn = book.Isbn,
                                Publisher = book.Publisher,
                                PublishYear = book.PublishYear,
                                Description = book.Description,
                                PageCount = book.PageCount,
                                CoverImageUrl = book.CoverImageUrl,
                                Source = "Image-based identification"
                            }
                        },
                        TotalResults = 1
                    };
                    
                    return Ok(response);
                }
                else
                {
                    _logger.LogWarning("⚠️ Image-based identification returned no results, falling back to text search");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Error during image-based identification, falling back to text search");
                // Continue to text-based search
            }
        }

        // Fallback to text-based search if no image or image search failed
        if (string.IsNullOrWhiteSpace(request.ExtractedText))
        {
            return BadRequest(new { error = "Either image data or extracted text is required" });
        }

        _logger.LogInformation("Using text-based cover search");
        var result = await _searchByCoverService.ExecuteAsync(request.ExtractedText);

        return Ok(result);
    }

    /// <summary>
    /// Identify a book from a cover image using Azure Computer Vision.
    /// </summary>
    /// <param name="request">Request containing Base64-encoded image data</param>
    /// <returns>Identified book information</returns>
    [HttpPost("identify-from-image")]
    [ProducesResponseType(typeof(BookResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> IdentifyFromImage([FromBody] IdentifyBookByImageRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ImageData))
        {
            return BadRequest(new { error = "Image data is required" });
        }

        try
        {
            _logger.LogInformation("Book identification request from image");

            // Convert Base64 to stream
            var imageBytes = Convert.FromBase64String(request.ImageData);
            using var imageStream = new MemoryStream(imageBytes);

            var book = await _searchByImageService.IdentifyBookAsync(imageStream);

            if (book == null)
            {
                return BadRequest(new { error = "Could not identify book from the provided image" });
            }

            var response = new BookResponse
            {
                Id = book.Id,
                Title = book.Title,
                Authors = book.Authors,
                Description = book.Description,
                Source = "Azure Vision"
            };

            return Ok(response);
        }
        catch (FormatException)
        {
            return BadRequest(new { error = "Invalid Base64 image data" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error identifying book from image");
            return StatusCode(500, new { error = "Error processing image", details = ex.Message });
        }
    }

    /// <summary>
    /// Save a book to the user's library in Azure Blob Storage.
    /// </summary>
    /// <param name="userId">The user identifier</param>
    /// <param name="book">Book information to save</param>
    /// <returns>Success message</returns>
    [HttpPost("library/{userId}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SaveToLibrary([FromRoute] string userId, [FromBody] BookResponse book)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest(new { error = "User ID is required" });
        }

        try
        {
            // For this simple example, we'll save the book data
            // In production, you'd want to manage a user's library collection
            var libraryJson = System.Text.Json.JsonSerializer.Serialize(new { book, savedAt = DateTime.UtcNow });
            
            var saved = await _libraryRepository.SaveUserLibraryAsync(userId, libraryJson);

            if (saved)
            {
                return Ok(new { message = "Book saved to library successfully", userId });
            }
            else
            {
                return StatusCode(500, new { error = "Failed to save book to library" });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving book to library");
            return StatusCode(500, new { error = "Error saving to library", details = ex.Message });
        }
    }

    /// <summary>
    /// Get the user's library from Azure Blob Storage.
    /// </summary>
    /// <param name="userId">The user identifier</param>
    /// <returns>User's library data</returns>
    [HttpGet("library/{userId}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUserLibrary([FromRoute] string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return BadRequest(new { error = "User ID is required" });
        }

        try
        {
            var libraryJson = await _libraryRepository.GetUserLibraryAsync(userId);

            if (libraryJson == null)
            {
                return NotFound(new { error = "Library not found for user", userId });
            }

            return Ok(new { data = libraryJson, userId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user library");
            return StatusCode(500, new { error = "Error retrieving library", details = ex.Message });
        }
    }
}
