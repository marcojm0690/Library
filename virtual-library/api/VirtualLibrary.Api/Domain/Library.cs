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
    /// User ID of the library owner (for user-scoped data)
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// Owner/creator of the library (legacy field for backward compatibility)
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

    /// <summary>
    /// Type of library (Read, ToRead, Reading, etc.)
    /// </summary>
    public LibraryType Type { get; set; } = LibraryType.Read;
}

/// <summary>
/// Types of libraries for categorizing reading status
/// </summary>
public enum LibraryType
{
    Read = 0,
    ToRead = 1,
    Reading = 2,
    Wishlist = 3,
    Favorites = 4
}
