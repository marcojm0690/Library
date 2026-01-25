using System.Text.Json;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Book provider that uses ISBNdb API
/// Free tier: 1000 requests/day
/// Sign up: https://isbndb.com/apidocs/v2
/// </summary>
public class ISBNdbBookProvider : IBookProvider
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<ISBNdbBookProvider> _logger;
    private readonly string? _apiKey;

    public string ProviderName => "ISBNdb";

    public ISBNdbBookProvider(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<ISBNdbBookProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = configuration["ISBNdb:ApiKey"];
        
        _httpClient.BaseAddress = new Uri("https://api2.isbndb.com/");
        if (!string.IsNullOrEmpty(_apiKey))
        {
            _httpClient.DefaultRequestHeaders.Add("Authorization", _apiKey);
        }
    }

    public async Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrEmpty(_apiKey))
        {
            _logger.LogWarning("ISBNdb API key not configured, skipping");
            return null;
        }

        try
        {
            var cleanIsbn = isbn.Replace("-", "").Replace(" ", "");
            var response = await _httpClient.GetAsync($"book/{cleanIsbn}");

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("ISBNdb returned {StatusCode} for ISBN {Isbn}", response.StatusCode, isbn);
                return null;
            }

            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<ISBNdbResponse>(content, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (result?.Book == null)
            {
                return null;
            }

            var book = result.Book;
            
            return new Book
            {
                Title = book.Title ?? "Unknown",
                Authors = book.Authors ?? new List<string>(),
                Publisher = book.Publisher,
                PublishYear = book.DatePublished != null ? ExtractYear(book.DatePublished) : null,
                PageCount = book.Pages,
                Description = book.Synopsis,
                Isbn = cleanIsbn,
                CoverImageUrl = book.Image, // ISBNdb provides cover URLs
                Source = "ISBNdb",
                ExternalId = book.Isbn13 ?? book.Isbn
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching book from ISBNdb for ISBN {Isbn}", isbn);
            return null;
        }
    }

    public Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        // Not implementing text search for now - focus on ISBN lookup
        return Task.FromResult(new List<Book>());
    }

    private static int? ExtractYear(string datePublished)
    {
        if (string.IsNullOrEmpty(datePublished))
            return null;

        // Try to parse year from various formats: "2024", "2024-01-01", etc.
        if (int.TryParse(datePublished.Substring(0, Math.Min(4, datePublished.Length)), out var year))
        {
            if (year >= 1000 && year <= DateTime.Now.Year + 1)
                return year;
        }

        return null;
    }

    // ISBNdb API response models
    private class ISBNdbResponse
    {
        public ISBNdbBook? Book { get; set; }
    }

    private class ISBNdbBook
    {
        public string? Title { get; set; }
        public string? TitleLong { get; set; }
        public string? Isbn { get; set; }
        public string? Isbn13 { get; set; }
        public string? Publisher { get; set; }
        public string? Language { get; set; }
        public string? DatePublished { get; set; }
        public int? Pages { get; set; }
        public string? Synopsis { get; set; }
        public string? Image { get; set; }
        public List<string>? Authors { get; set; }
    }
}
