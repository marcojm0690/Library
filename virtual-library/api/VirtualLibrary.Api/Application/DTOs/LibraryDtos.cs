namespace VirtualLibrary.Api.Application.DTOs;

/// <summary>
/// Request DTO for creating a new library
/// </summary>
public record CreateLibraryRequest
{
    public string Name { get; init; } = string.Empty;
    public string? Description { get; init; }
    public string Owner { get; init; } = string.Empty;
    public List<string>? Tags { get; init; }
    public bool IsPublic { get; init; } = false;
}

/// <summary>
/// Response DTO for library information
/// </summary>
public record LibraryResponse
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string? Description { get; init; }
    public string Owner { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
    public List<Guid> BookIds { get; init; } = new();
    public int BookCount { get; init; }
    public List<string> Tags { get; init; } = new();
    public bool IsPublic { get; init; }
}

/// <summary>
/// Request DTO for updating a library
/// </summary>
public record UpdateLibraryRequest
{
    public string? Name { get; init; }
    public string? Description { get; init; }
    public List<string>? Tags { get; init; }
    public bool? IsPublic { get; init; }
}

/// <summary>
/// Request DTO for adding books to a library
/// </summary>
public record AddBooksToLibraryRequest
{
    public List<Guid> BookIds { get; init; } = new();
}

/// <summary>
/// Response DTO for vocabulary hints used in speech recognition
/// </summary>
public record VocabularyHintsResponse
{
    /// <summary>
    /// List of vocabulary hints (authors, titles, publishers, etc.)
    /// </summary>
    public List<string> Hints { get; init; } = new();
    
    /// <summary>
    /// Tags from the user's libraries
    /// </summary>
    public List<string> Tags { get; init; } = new();
    
    /// <summary>
    /// Total number of books in user's libraries
    /// </summary>
    public int BookCount { get; init; }
    
    /// <summary>
    /// Whether the hints are personalized based on user's library or general
    /// </summary>
    public bool IsPersonalized { get; init; }
}
