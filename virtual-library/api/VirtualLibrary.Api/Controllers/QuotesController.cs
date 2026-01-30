using Microsoft.AspNetCore.Mvc;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Domain;
using VirtualLibrary.Api.Infrastructure;
using VirtualLibrary.Api.Infrastructure.Cache;
using VirtualLibrary.Api.Infrastructure.External;

namespace VirtualLibrary.Api.Controllers;

/// <summary>
/// Controller for quote verification and management
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class QuotesController : ControllerBase
{
    private readonly IBookRepository _bookRepository;
    private readonly GoogleBooksProvider _googleBooksProvider;
    private readonly OpenLibraryProvider _openLibraryProvider;
    private readonly RedisCacheService _cache;
    private readonly ILogger<QuotesController> _logger;

    public QuotesController(
        IBookRepository bookRepository,
        GoogleBooksProvider googleBooksProvider,
        OpenLibraryProvider openLibraryProvider,
        RedisCacheService cache,
        ILogger<QuotesController> logger)
    {
        _bookRepository = bookRepository;
        _googleBooksProvider = googleBooksProvider;
        _openLibraryProvider = openLibraryProvider;
        _cache = cache;
        _logger = logger;
    }

    /// <summary>
    /// Verify a quote and get information about its source
    /// </summary>
    [HttpPost("verify")]
    [ProducesResponseType(typeof(QuoteVerificationResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<QuoteVerificationResponse>> VerifyQuote([FromBody] QuoteVerificationRequest request)
    {
        _logger.LogInformation("Verifying quote: {Quote}", request.QuoteText?.Substring(0, Math.Min(50, request.QuoteText?.Length ?? 0)));

        if (string.IsNullOrWhiteSpace(request.QuoteText))
        {
            return BadRequest(new { error = "Quote text is required" });
        }

        // Check cache first
        var cacheKey = $"quote:verify:{request.QuoteText.GetHashCode()}";
        var cachedResult = await _cache.GetAsync<QuoteVerificationResponse>(cacheKey);
        if (cachedResult != null)
        {
            _logger.LogInformation("Cache hit for quote verification");
            return Ok(cachedResult);
        }

        var response = new QuoteVerificationResponse
        {
            OriginalQuote = request.QuoteText,
            ClaimedAuthor = request.ClaimedAuthor,
            InputMethod = request.InputMethod,
            PossibleSources = new List<QuoteSource>()
        };

        try
        {
            // Strategy 1: Search in user's library if they provided userId
            if (!string.IsNullOrWhiteSpace(request.UserId))
            {
                await SearchInUserLibrary(request, response);
            }

            // Strategy 2: Search Google Books
            await SearchGoogleBooks(request, response);

            // Strategy 3: Search Open Library
            await SearchOpenLibrary(request, response);

            // Calculate overall confidence
            response.OverallConfidence = CalculateConfidence(response);
            response.IsVerified = response.OverallConfidence >= 0.6;
            response.AuthorVerified = VerifyAuthor(response, request.ClaimedAuthor);

            // Add context and recommendations
            if (response.PossibleSources.Any())
            {
                response.Context = GenerateContext(response.PossibleSources.First());
                response.RecommendedBook = response.PossibleSources.First().Book;
            }

            // Cache result for 24 hours
            await _cache.SetAsync(cacheKey, response, TimeSpan.FromHours(24));

            _logger.LogInformation(
                "Quote verification complete. Confidence: {Confidence:P}, IsVerified: {IsVerified}, AuthorVerified: {AuthorVerified}, Sources: {Count}", 
                response.OverallConfidence, response.IsVerified, response.AuthorVerified, response.PossibleSources.Count);
            
            if (response.PossibleSources.Any())
            {
                _logger.LogDebug("Top source: {Title} by {Author} - Confidence: {Confidence:P}", 
                    response.PossibleSources.First().Book.Title,
                    string.Join(", ", response.PossibleSources.First().Book.Authors),
                    response.PossibleSources.First().Confidence);
            }

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying quote");
            return StatusCode(500, new { error = "Failed to verify quote" });
        }
    }

    private async Task SearchInUserLibrary(QuoteVerificationRequest request, QuoteVerificationResponse response)
    {
        // TODO: Search user's library books for quotes
        // This would require full-text search in book descriptions/content
        _logger.LogInformation("Searching user library for quote");
    }

    private async Task SearchGoogleBooks(QuoteVerificationRequest request, QuoteVerificationResponse response)
    {
        try
        {
            // Search for quote text
            var searchQuery = $"\"{request.QuoteText}\"";
            if (!string.IsNullOrWhiteSpace(request.ClaimedAuthor))
            {
                searchQuery += $" {request.ClaimedAuthor}";
            }

            var books = await _googleBooksProvider.SearchByTextAsync(searchQuery);

            foreach (var book in books.Take(5))
            {
                // Check if book description contains the quote
                var confidence = CalculateQuoteMatch(request.QuoteText, book.Description);
                
                if (confidence > 0.3) // Only include if there's some match
                {
                    response.PossibleSources.Add(new QuoteSource
                    {
                        Book = book,
                        Confidence = confidence,
                        MatchType = "Description Match",
                        Source = "Google Books"
                    });
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error searching Google Books for quote");
        }
    }

    private async Task SearchOpenLibrary(QuoteVerificationRequest request, QuoteVerificationResponse response)
    {
        try
        {
            var searchQuery = request.ClaimedAuthor ?? request.QuoteText.Split(' ').Take(3).Aggregate((a, b) => a + " " + b);
            var books = await _openLibraryProvider.SearchByTextAsync(searchQuery);

            foreach (var book in books.Take(3))
            {
                // Calculate confidence based on description match if available
                var confidence = CalculateQuoteMatch(request.QuoteText, book.Description);
                
                // If no description or low match, use author match as fallback
                if (confidence < 0.3 && !string.IsNullOrWhiteSpace(request.ClaimedAuthor))
                {
                    var authorMatch = book.Authors.Any(a => 
                        a.ToLower().Contains(request.ClaimedAuthor.ToLower()) || 
                        request.ClaimedAuthor.ToLower().Contains(a.ToLower()));
                    
                    if (authorMatch)
                    {
                        confidence = 0.35; // Lower confidence for author-only match
                    }
                }
                
                // Only add sources with meaningful confidence
                if (confidence >= 0.3)
                {
                    response.PossibleSources.Add(new QuoteSource
                    {
                        Book = book,
                        Confidence = confidence,
                        MatchType = confidence >= 0.5 ? "Description Match" : "Author Match",
                        Source = "Open Library"
                    });
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error searching Open Library for quote");
        }
    }

    private double CalculateQuoteMatch(string quote, string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return 0;

        var quoteWords = quote.ToLower().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var textLower = text.ToLower();

        // Calculate how many quote words appear in the text
        var matchingWords = quoteWords.Count(w => textLower.Contains(w));
        var wordMatchRatio = (double)matchingWords / quoteWords.Length;

        // Check for exact substring match
        if (textLower.Contains(quote.ToLower()))
            return 0.95;

        // Check for close match (80%+ of words)
        if (wordMatchRatio >= 0.8)
            return 0.7 + (wordMatchRatio - 0.8) * 0.5;

        return wordMatchRatio * 0.5;
    }

    private double CalculateConfidence(QuoteVerificationResponse response)
    {
        if (!response.PossibleSources.Any())
            return 0;

        // Use the highest confidence source as the primary indicator
        var maxConfidence = response.PossibleSources.Max(s => s.Confidence);
        
        // If we have multiple high-confidence sources, boost the overall confidence
        var highConfidenceSources = response.PossibleSources.Count(s => s.Confidence >= 0.6);
        if (highConfidenceSources >= 2)
        {
            return Math.Min(0.95, maxConfidence + 0.1);
        }
        
        // If we only have one source, use weighted average with emphasis on the top source
        var topSources = response.PossibleSources.OrderByDescending(s => s.Confidence).Take(3).ToList();
        if (topSources.Count == 1)
        {
            return topSources[0].Confidence;
        }
        
        // Weighted average: top source 60%, second 25%, third 15%
        var weights = new[] { 0.6, 0.25, 0.15 };
        double weightedSum = 0;
        double totalWeight = 0;
        
        for (int i = 0; i < Math.Min(topSources.Count, weights.Length); i++)
        {
            weightedSum += topSources[i].Confidence * weights[i];
            totalWeight += weights[i];
        }
        
        return weightedSum / totalWeight;
    }

    private bool VerifyAuthor(QuoteVerificationResponse response, string? claimedAuthor)
    {
        if (string.IsNullOrWhiteSpace(claimedAuthor))
            return false;

        var authorLower = claimedAuthor.ToLower();
        
        foreach (var source in response.PossibleSources)
        {
            if (source.Book.Authors.Any(a => a.ToLower().Contains(authorLower) || authorLower.Contains(a.ToLower())))
            {
                return true;
            }
        }

        return false;
    }

    private string GenerateContext(QuoteSource source)
    {
        var context = $"This quote appears to be from \"{source.Book.Title}\"";
        
        if (source.Book.Authors.Any())
        {
            context += $" by {string.Join(", ", source.Book.Authors)}";
        }

        if (source.Book.PublishYear.HasValue)
        {
            context += $", published in {source.Book.PublishYear}";
        }

        context += $". {source.Book.Description?.Substring(0, Math.Min(200, source.Book.Description?.Length ?? 0))}";

        return context;
    }
}

// DTOs
public class QuoteVerificationRequest
{
    public string QuoteText { get; set; } = string.Empty;
    public string? ClaimedAuthor { get; set; }
    public string? UserId { get; set; }
    public string InputMethod { get; set; } = "text"; // text, voice, photo
}

public class QuoteVerificationResponse
{
    public string OriginalQuote { get; set; } = string.Empty;
    public string? ClaimedAuthor { get; set; }
    public bool IsVerified { get; set; }
    public bool AuthorVerified { get; set; }
    public double OverallConfidence { get; set; }
    public string InputMethod { get; set; } = string.Empty;
    public List<QuoteSource> PossibleSources { get; set; } = new();
    public string? Context { get; set; }
    public Book? RecommendedBook { get; set; }
}

public class QuoteSource
{
    public Book Book { get; set; } = new();
    public double Confidence { get; set; }
    public string MatchType { get; set; } = string.Empty;
    public string Source { get; set; } = string.Empty;
    public string? Chapter { get; set; }
    public int? PageNumber { get; set; }
}
