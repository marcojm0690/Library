namespace VirtualLibrary.Api.Domain;

/// <summary>
/// Domain entity representing a library collection.
/// A library can contain multiple books and has ownership information.
/// </summary>
public class Library
{
    /// <summary>
    /// Unique identifier for the library
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// Name of the library
    /// </summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Optional description of the library
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    /// Owner/creator of the library
    /// </summary>
    public string Owner { get; set; } = string.Empty;

    /// <summary>
    /// Date when the library was created
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Date when the library was last updated
    /// </summary>
    public DateTime UpdatedAt { get; set; }

    /// <summary>
    /// List of book IDs in this library
    /// </summary>
    public List<Guid> BookIds { get; set; } = new();

    /// <summary>
    /// Tags for categorizing the library
    /// </summary>
    public List<string> Tags { get; set; } = new();

    /// <summary>
    /// Whether the library is public or private
    /// </summary>
    public bool IsPublic { get; set; } = false;
}
