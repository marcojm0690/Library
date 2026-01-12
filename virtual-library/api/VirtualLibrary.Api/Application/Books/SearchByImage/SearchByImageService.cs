using VirtualLibrary.Api.Domain;
using VirtualLibrary.Api.Infrastructure.External;

namespace VirtualLibrary.Api.Application.Books.SearchByImage;

/// <summary>
/// Service for identifying books from cover images using Azure Computer Vision.
/// </summary>
public class SearchByImageService
{
    private readonly AzureVisionProvider _visionProvider;
    private readonly ILogger<SearchByImageService> _logger;

    public SearchByImageService(AzureVisionProvider visionProvider, ILogger<SearchByImageService> logger)
    {
        _visionProvider = visionProvider;
        _logger = logger;
    }

    /// <summary>
    /// Analyzes a book cover image and identifies the book.
    /// </summary>
    /// <param name="imageStream">Stream containing the book cover image</param>
    /// <returns>Identified book information</returns>
    public async Task<Book?> IdentifyBookAsync(Stream imageStream)
    {
        _logger.LogInformation("Starting book identification from image");
        
        var book = await _visionProvider.IdentifyFromImageAsync(imageStream);
        
        if (book == null)
        {
            _logger.LogWarning("Could not identify book from provided image");
        }

        return book;
    }
}
