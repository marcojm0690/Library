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
    private readonly GoogleBooksProvider _googleBooksProvider;
    private readonly ILogger<AzureVisionProvider> _logger;

    public string ProviderName => "AzureVision";

    public AzureVisionProvider(
        IConfiguration configuration, 
        GoogleBooksProvider googleBooksProvider,
        ILogger<AzureVisionProvider> logger)
    {
        _logger = logger;
        _googleBooksProvider = googleBooksProvider;
        
        var endpoint = configuration["Azure:Vision:Endpoint"]
            ?? throw new InvalidOperationException("Azure Vision endpoint not configured");

        var credential = new DefaultAzureCredential();
        _client = new ImageAnalysisClient(new Uri(endpoint), credential);
    }

    /// <summary>
    /// Analyzes a book cover image and returns identified book information.
    /// Uses OCR to extract text from the cover and searches Google Books API.
    /// </summary>
    /// <param name="imageStream">Stream containing the book cover image</param>
    /// <returns>Identified book information or null if not found</returns>
    public async Task<Book?> IdentifyFromImageAsync(Stream imageStream)
    {
        try
        {
            _logger.LogInformation("🔍 Analyzing book cover image with Azure Vision OCR");

            // Reset stream position
            if (imageStream.CanSeek)
            {
                imageStream.Position = 0;
            }

            // Convert stream to byte array
            using var memoryStream = new MemoryStream();
            await imageStream.CopyToAsync(memoryStream);
            var imageData = BinaryData.FromBytes(memoryStream.ToArray());

            // Analyze the image with OCR (Read feature)
            var analysisResult = await _client.AnalyzeAsync(
                imageData,
                VisualFeatures.Read);

            // Extract text from OCR results
            var extractedText = string.Empty;
            if (analysisResult.Value.Read?.Blocks != null)
            {
                var textLines = analysisResult.Value.Read.Blocks
                    .SelectMany(block => block.Lines)
                    .Select(line => line.Text);
                
                extractedText = string.Join(" ", textLines);
                _logger.LogInformation("📝 Extracted text from image: {Text}", extractedText);
            }

            // If we have extracted text, search Google Books
            if (!string.IsNullOrWhiteSpace(extractedText))
            {
                _logger.LogInformation("🔎 Searching Google Books with extracted text...");
                var books = await _googleBooksProvider.SearchByTextAsync(extractedText);
                
                if (books.Any())
                {
                    var firstBook = books.First();
                    _logger.LogInformation("✅ Found book: {Title} by {Authors}", 
                        firstBook.Title, 
                        string.Join(", ", firstBook.Authors));
                    
                    // Mark the source as Vision API
                    firstBook.Source = "Vision API + Google Books";
                    return firstBook;
                }
                else
                {
                    _logger.LogWarning("⚠️ No books found in Google Books for extracted text");
                }
            }
            else
            {
                _logger.LogWarning("⚠️ No text extracted from image");
            }

            // Return null if no book found
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error analyzing book cover with Azure Vision: {Message}", ex.Message);
            return null;
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
