using Microsoft.AspNetCore.Mvc;
using VirtualLibrary.Application.DTOs;
using VirtualLibrary.Application.Interfaces;

namespace VirtualLibrary.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BooksController : ControllerBase
{
    private readonly IBookLookupService _bookLookupService;
    private readonly IImageRecognitionService _imageRecognitionService;
    private readonly ILogger<BooksController> _logger;

    public BooksController(
        IBookLookupService bookLookupService,
        IImageRecognitionService imageRecognitionService,
        ILogger<BooksController> logger)
    {
        _bookLookupService = bookLookupService;
        _imageRecognitionService = imageRecognitionService;
        _logger = logger;
    }

    /// <summary>
    /// Look up a book by ISBN barcode
    /// </summary>
    /// <param name="request">The ISBN lookup request</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Book information if found</returns>
    [HttpPost("lookup")]
    [ProducesResponseType(typeof(BookLookupResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<BookLookupResponse>> LookupBook(
        [FromBody] BookLookupRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.ISBN))
            {
                return BadRequest(new BookLookupResponse
                {
                    Success = false,
                    Message = "ISBN is required"
                });
            }

            _logger.LogInformation("Looking up book with ISBN: {ISBN}", request.ISBN);

            var book = await _bookLookupService.LookupBookByISBNAsync(request.ISBN, cancellationToken);

            if (book == null)
            {
                return Ok(new BookLookupResponse
                {
                    Success = false,
                    Message = "Book not found"
                });
            }

            var bookDto = new BookDto
            {
                ISBN = book.ISBN,
                Title = book.Title,
                Author = book.Author,
                Publisher = book.Publisher,
                PublicationYear = book.PublicationYear,
                Description = book.Description,
                CoverImageUrl = book.CoverImageUrl,
                Categories = book.Categories
            };

            return Ok(new BookLookupResponse
            {
                Success = true,
                Message = "Book found successfully",
                Book = bookDto
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error looking up book with ISBN: {ISBN}", request.ISBN);
            return StatusCode(500, new BookLookupResponse
            {
                Success = false,
                Message = "An error occurred while looking up the book"
            });
        }
    }

    /// <summary>
    /// Search for books by analyzing a cover image using OCR
    /// </summary>
    /// <param name="request">The cover image search request (base64 encoded image)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of matching books</returns>
    [HttpPost("search-by-cover")]
    [ProducesResponseType(typeof(SearchByCoverResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SearchByCoverResponse>> SearchByCover(
        [FromBody] SearchByCoverRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.ImageBase64))
            {
                return BadRequest(new SearchByCoverResponse
                {
                    Success = false,
                    Message = "Image data is required"
                });
            }

            _logger.LogInformation("Searching for books by cover image");

            var books = await _imageRecognitionService.SearchBooksByCoverImageAsync(request.ImageBase64, cancellationToken);

            var bookDtos = books.Select(book => new BookDto
            {
                ISBN = book.ISBN,
                Title = book.Title,
                Author = book.Author,
                Publisher = book.Publisher,
                PublicationYear = book.PublicationYear,
                Description = book.Description,
                CoverImageUrl = book.CoverImageUrl,
                Categories = book.Categories
            }).ToList();

            return Ok(new SearchByCoverResponse
            {
                Success = true,
                Message = $"Found {bookDtos.Count} book(s)",
                Books = bookDtos
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching for books by cover image");
            return StatusCode(500, new SearchByCoverResponse
            {
                Success = false,
                Message = "An error occurred while searching for books"
            });
        }
    }
}
