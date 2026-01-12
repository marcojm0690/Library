namespace VirtualLibrary.Api.Application.DTOs;

/// <summary>
/// Request DTO for looking up a book by ISBN
/// </summary>
public record LookupByIsbnRequest
{
    /// <summary>
    /// The ISBN-10 or ISBN-13 to search for
    /// </summary>
    public string Isbn { get; init; } = string.Empty;
}

/// <summary>
/// Request DTO for searching books by cover text (OCR results)
/// </summary>
public record SearchByCoverRequest
{
    /// <summary>
    /// Text extracted from the book cover via OCR
    /// </summary>
    public string ExtractedText { get; init; } = string.Empty;

    /// <summary>
    /// Optional: Base64-encoded image for future ML enhancement
    /// </summary>
    public string? ImageData { get; init; }
}

/// <summary>
/// Response DTO containing book information
/// </summary>
public record BookResponse
{
    public Guid? Id { get; init; }
    public string? Isbn { get; init; }
    public string Title { get; init; } = string.Empty;
    public List<string> Authors { get; init; } = new();
    public string? Publisher { get; init; }
    public int? PublishYear { get; init; }
    public string? CoverImageUrl { get; init; }
    public string? Description { get; init; }
    public int? PageCount { get; init; }
    public string? Source { get; init; }
}

/// <summary>
/// Response wrapper for search results that may contain multiple books
/// </summary>
public record SearchBooksResponse
{
    public List<BookResponse> Books { get; init; } = new();
    public int TotalResults { get; init; }
}

/// <summary>
/// Request DTO for identifying books from cover images
/// </summary>
public record IdentifyBookByImageRequest
{
    /// <summary>
    /// Base64-encoded image data or image bytes
    /// </summary>
    public string ImageData { get; init; } = string.Empty;

    /// <summary>
    /// Image format (e.g., "jpg", "png")
    /// </summary>
    public string ImageFormat { get; init; } = "jpg";
}
