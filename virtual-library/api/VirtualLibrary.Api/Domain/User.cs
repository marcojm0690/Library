namespace VirtualLibrary.Api.Domain;

/// <summary>
/// Domain entity representing an authenticated user
/// </summary>
public class User
{
    /// <summary>
    /// Unique identifier for the user
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// External provider's user ID (e.g., Microsoft ID)
    /// </summary>
    public string ExternalId { get; set; } = string.Empty;

    /// <summary>
    /// OAuth provider name (e.g., "microsoft")
    /// </summary>
    public string Provider { get; set; } = string.Empty;

    /// <summary>
    /// User's email address
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// User's display name
    /// </summary>
    public string? DisplayName { get; set; }

    /// <summary>
    /// User's profile picture URL
    /// </summary>
    public string? ProfilePictureUrl { get; set; }

    /// <summary>
    /// Date when the user was created
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Date when the user last logged in
    /// </summary>
    public DateTime LastLoginAt { get; set; }
}
