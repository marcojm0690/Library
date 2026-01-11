using Microsoft.AspNetCore.Mvc;
using VirtualLibrary.Api.Application.Books.SearchByIsbn;
using VirtualLibrary.Api.Application.Books.SearchByCover;
using VirtualLibrary.Api.Application.DTOs;

namespace VirtualLibrary.Api.Controllers;

/// <summary>
/// API controller for book-related operations.
/// Provides endpoints for ISBN lookup and cover-based search.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class BooksController : ControllerBase
{
    private readonly SearchByIsbnService _searchByIsbnService;
    private readonly SearchByCoverService _searchByCoverService;
    private readonly ILogger<BooksController> _logger;

    public BooksController(
        SearchByIsbnService searchByIsbnService,
        SearchByCoverService searchByCoverService,
        ILogger<BooksController> logger)
    {
        _searchByIsbnService = searchByIsbnService;
        _searchByCoverService = searchByCoverService;
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
    /// Search for books based on text extracted from cover image (OCR).
    /// </summary>
    /// <param name="request">Request containing OCR-extracted text</param>
    /// <returns>List of potential book matches</returns>
    [HttpPost("search-by-cover")]
    [ProducesResponseType(typeof(SearchBooksResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SearchByCover([FromBody] SearchByCoverRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ExtractedText))
        {
            return BadRequest(new { error = "Extracted text is required" });
        }

        _logger.LogInformation("Cover search request with text length: {Length}", request.ExtractedText.Length);

        var result = await _searchByCoverService.ExecuteAsync(request.ExtractedText);

        return Ok(result);
    }
}
