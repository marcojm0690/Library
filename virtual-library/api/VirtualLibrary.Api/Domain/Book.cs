namespace VirtualLibrary.Api.Domain;

/// <summary>
/// Domain entity representing a book in the virtual library.
/// Contains core book information that can be identified via ISBN or cover scanning.
/// </summary>
public class Book
{
    /// <summary>
    /// Unique identifier for the book (internal system ID)
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// International Standard Book Number
    /// </summary>
    public string? Isbn { get; set; }

    /// <summary>
    /// Book title
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// Primary author(s) of the book
    /// </summary>
    public List<string> Authors { get; set; } = new();

    /// <summary>
    /// Publisher name
    /// </summary>
    public string? Publisher { get; set; }

    /// <summary>
    /// Year of publication
    /// </summary>
    public int? PublishYear { get; set; }

    /// <summary>
    /// URL to the book cover image
    /// </summary>
    public string? CoverImageUrl { get; set; }

    /// <summary>
    /// Short description or synopsis
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    /// Number of pages
    /// </summary>
    public int? PageCount { get; set; }

    /// <summary>
    /// External source identifier (e.g., from Google Books or Open Library)
    /// </summary>
    public string? ExternalId { get; set; }

    /// <summary>
    /// Source provider (e.g., "GoogleBooks", "OpenLibrary")
    /// </summary>
    public string? Source { get; set; }
}
