using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace VirtualLibrary.Api.Infrastructure.Persistence;

/// <summary>
/// Service for managing user library storage in Azure Blob Storage.
/// Handles saving, retrieving, and deleting user library data.
/// </summary>
public class AzureBlobLibraryRepository
{
    private readonly BlobContainerClient _containerClient;
    private readonly ILogger<AzureBlobLibraryRepository> _logger;

    public AzureBlobLibraryRepository(IConfiguration configuration, ILogger<AzureBlobLibraryRepository> logger)
    {
        _logger = logger;
        
        var connectionString = configuration["Azure:Storage:ConnectionString"]
            ?? throw new InvalidOperationException("Azure Storage connection string not configured");
        var containerName = configuration["Azure:Storage:ContainerName"]
            ?? throw new InvalidOperationException("Azure Storage container name not configured");

        var blobClient = new BlobContainerClient(connectionString, containerName);
        _containerClient = blobClient;
    }

    /// <summary>
    /// Saves a user's book library to Azure Blob Storage.
    /// </summary>
    /// <param name="userId">The user identifier</param>
    /// <param name="libraryData">JSON string containing the user's book library</param>
    /// <returns>True if successful, false otherwise</returns>
    public async Task<bool> SaveUserLibraryAsync(string userId, string libraryData)
    {
        try
        {
            var blobName = $"users/{userId}/library.json";
            var blobClient = _containerClient.GetBlobClient(blobName);

            await blobClient.UploadAsync(
                BinaryData.FromString(libraryData),
                overwrite: true);

            _logger.LogInformation("User library saved for user {UserId}", userId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving user library for user {UserId}", userId);
            return false;
        }
    }

    /// <summary>
    /// Retrieves a user's book library from Azure Blob Storage.
    /// </summary>
    /// <param name="userId">The user identifier</param>
    /// <returns>JSON string of the user's library, or null if not found</returns>
    public async Task<string?> GetUserLibraryAsync(string userId)
    {
        try
        {
            var blobName = $"users/{userId}/library.json";
            var blobClient = _containerClient.GetBlobClient(blobName);

            if (!await blobClient.ExistsAsync())
            {
                _logger.LogWarning("User library not found for user {UserId}", userId);
                return null;
            }

            var download = await blobClient.DownloadAsync();
            var content = await new StreamReader(download.Value.Content).ReadToEndAsync();

            _logger.LogInformation("User library retrieved for user {UserId}", userId);
            return content;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user library for user {UserId}", userId);
            return null;
        }
    }

    /// <summary>
    /// Saves a book cover image to Azure Blob Storage.
    /// </summary>
    /// <param name="userId">The user identifier</param>
    /// <param name="bookId">The book identifier</param>
    /// <param name="imageStream">Stream containing the image data</param>
    /// <returns>URL of the saved image, or null if failed</returns>
    public async Task<string?> SaveBookCoverAsync(string userId, string bookId, Stream imageStream)
    {
        try
        {
            var blobName = $"users/{userId}/covers/{bookId}.jpg";
            var blobClient = _containerClient.GetBlobClient(blobName);

            imageStream.Position = 0;
            await blobClient.UploadAsync(imageStream, overwrite: true);

            _logger.LogInformation("Book cover saved for book {BookId} user {UserId}", bookId, userId);
            return blobClient.Uri.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving book cover for user {UserId}", userId);
            return null;
        }
    }

    /// <summary>
    /// Deletes a user's library from Azure Blob Storage.
    /// </summary>
    /// <param name="userId">The user identifier</param>
    /// <returns>True if successful, false otherwise</returns>
    public async Task<bool> DeleteUserLibraryAsync(string userId)
    {
        try
        {
            var blobName = $"users/{userId}/library.json";
            var blobClient = _containerClient.GetBlobClient(blobName);

            await blobClient.DeleteAsync();
            _logger.LogInformation("User library deleted for user {UserId}", userId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting user library for user {UserId}", userId);
            return false;
        }
    }
}
