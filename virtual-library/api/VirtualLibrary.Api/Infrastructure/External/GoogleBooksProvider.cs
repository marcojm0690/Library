using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Google Books API integration.
/// Documentation: https://developers.google.com/books/docs/v1/using
/// </summary>
public class GoogleBooksProvider : IBookProvider
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<GoogleBooksProvider> _logger;

    public string ProviderName => "GoogleBooks";

    public GoogleBooksProvider(HttpClient httpClient, ILogger<GoogleBooksProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        
        _httpClient.BaseAddress = new Uri("https://www.googleapis.com/books/v1/");
    }

    public async Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("GoogleBooks: Searching for ISBN {Isbn}", isbn);
            
            var response = await _httpClient.GetAsync($"volumes?q=isbn:{isbn}", cancellationToken);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("GoogleBooks API returned {StatusCode}", response.StatusCode);
                return null;
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            var result = JsonSerializer.Deserialize<GoogleBooksResponse>(content);

            if (result?.Items == null || result.Items.Count == 0)
            {
                return null;
            }

            return MapToBook(result.Items[0]);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching GoogleBooks for ISBN {Isbn}", isbn);
            return null;
        }
    }

    public async Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("GoogleBooks: Searching for text: {Text}", searchText);
            
            var response = await _httpClient.GetAsync($"volumes?q={Uri.EscapeDataString(searchText)}&maxResults=10", cancellationToken);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("GoogleBooks API returned {StatusCode}", response.StatusCode);
                return new List<Book>();
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            var result = JsonSerializer.Deserialize<GoogleBooksResponse>(content);

            if (result?.Items == null || result.Items.Count == 0)
            {
                return new List<Book>();
            }

            return result.Items.Select(MapToBook).Where(b => b != null).Cast<Book>().ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching GoogleBooks for text: {Text}", searchText);
            return new List<Book>();
        }
    }

    private Book? MapToBook(GoogleBookItem item)
    {
        if (item?.VolumeInfo == null) return null;

        var volumeInfo = item.VolumeInfo;
        
        return new Book
        {
            Id = Guid.NewGuid(),
            Title = volumeInfo.Title ?? "Unknown",
            Authors = volumeInfo.Authors ?? new List<string>(),
            Publisher = volumeInfo.Publisher,
            PublishYear = ExtractYear(volumeInfo.PublishedDate),
            Description = volumeInfo.Description,
            PageCount = volumeInfo.PageCount,
            Isbn = volumeInfo.IndustryIdentifiers?.FirstOrDefault()?.Identifier,
            CoverImageUrl = volumeInfo.ImageLinks?.Thumbnail,
            Source = ProviderName,
            ExternalId = item.Id
        };
    }

    private int? ExtractYear(string? publishedDate)
    {
        if (string.IsNullOrEmpty(publishedDate)) return null;
        if (publishedDate.Length >= 4 && int.TryParse(publishedDate.Substring(0, 4), out int year))
        {
            return year;
        }
        return null;
    }
}

// Google Books API response models
public class GoogleBooksResponse
{
    [JsonPropertyName("items")]
    public List<GoogleBookItem>? Items { get; set; }
}

public class GoogleBookItem
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }
    
    [JsonPropertyName("volumeInfo")]
    public VolumeInfo? VolumeInfo { get; set; }
}

public class VolumeInfo
{
    [JsonPropertyName("title")]
    public string? Title { get; set; }
    
    [JsonPropertyName("authors")]
    public List<string>? Authors { get; set; }
    
    [JsonPropertyName("publisher")]
    public string? Publisher { get; set; }
    
    [JsonPropertyName("publishedDate")]
    public string? PublishedDate { get; set; }
    
    [JsonPropertyName("description")]
    public string? Description { get; set; }
    
    [JsonPropertyName("pageCount")]
    public int? PageCount { get; set; }
    
    [JsonPropertyName("imageLinks")]
    public ImageLinks? ImageLinks { get; set; }
    
    [JsonPropertyName("industryIdentifiers")]
    public List<IndustryIdentifier>? IndustryIdentifiers { get; set; }
}

public class ImageLinks
{
    [JsonPropertyName("thumbnail")]
    public string? Thumbnail { get; set; }
}

public class IndustryIdentifier
{
    [JsonPropertyName("type")]
    public string? Type { get; set; }
    
    [JsonPropertyName("identifier")]
    public string? Identifier { get; set; }
}
