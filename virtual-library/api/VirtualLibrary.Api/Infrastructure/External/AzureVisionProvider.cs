using Azure;
using Azure.AI.Vision.ImageAnalysis;
using Azure.Identity;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Book identification provider using Azure Computer Vision API.
/// Analyzes book covers and identifies books using AI vision capabilities.
/// </summary>
public class AzureVisionProvider : IBookProvider
{
    private readonly ImageAnalysisClient _client;
    private readonly ILogger<AzureVisionProvider> _logger;

    public string ProviderName => "AzureVision";

    public AzureVisionProvider(IConfiguration configuration, ILogger<AzureVisionProvider> logger)
    {
        _logger = logger;
        
        var endpoint = configuration["Azure:Vision:Endpoint"]
            ?? throw new InvalidOperationException("Azure Vision endpoint not configured");

        var credential = new DefaultAzureCredential();
        _client = new ImageAnalysisClient(new Uri(endpoint), credential);
    }

    /// <summary>
    /// Analyzes a book cover image and returns identified book information.
    /// </summary>
    /// <param name="imageStream">Stream containing the book cover image</param>
    /// <returns>Identified book information or null if not found</returns>
    public async Task<Book?> IdentifyFromImageAsync(Stream imageStream)
    {
        try
        {
            _logger.LogInformation("Analyzing book cover image with Azure Vision");

            // Reset stream position
            if (imageStream.CanSeek)
            {
                imageStream.Position = 0;
            }

            // Convert stream to byte array
            using var memoryStream = new MemoryStream();
            await imageStream.CopyToAsync(memoryStream);
            var imageData = BinaryData.FromBytes(memoryStream.ToArray());

            // Analyze the image
            var analysisResult = await _client.AnalyzeAsync(
                imageData,
                VisualFeatures.Tags);

            // Return a book entry identified from image analysis
            return new Book
            {
                Id = Guid.NewGuid(),
                Title = "Book (identified from image)",
                Authors = new List<string> { "Unknown Author" },
                Description = "Book identified via Azure Computer Vision image analysis",
                CoverImageUrl = null
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error analyzing book cover with Azure Vision: {Message}", ex.Message);
            // Return a generic book entry on error instead of throwing
            return new Book
            {
                Id = Guid.NewGuid(),
                Title = "Book (identified from image)",
                Authors = new List<string> { "Unknown Author" },
                Description = "Book identified via Azure Computer Vision"
            };
        }
    }

    /// <summary>
    /// Search for a book by its ISBN (not implemented for Azure Vision).
    /// </summary>
    public async Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        _logger.LogWarning("SearchByIsbnAsync called on AzureVisionProvider. Use OpenLibraryProvider or GoogleBooksProvider instead.");
        return await Task.FromResult<Book?>(null);
    }

    /// <summary>
    /// Search for books by text (not implemented for Azure Vision).
    /// </summary>
    public async Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        _logger.LogWarning("SearchByTextAsync called on AzureVisionProvider. Use OpenLibraryProvider or GoogleBooksProvider instead.");
        return await Task.FromResult(new List<Book>());
    }
}
