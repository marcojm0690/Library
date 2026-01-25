using System.Text.Json;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Book provider that uses Inventaire.io API
/// Free, open, supports ISBN and title search, good for covers
/// API docs: https://wiki.inventaire.io/wiki/API
/// </summary>
public class InventaireBookProvider : IBookProvider
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<InventaireBookProvider> _logger;
    public string ProviderName => "Inventaire";

    public InventaireBookProvider(HttpClient httpClient, ILogger<InventaireBookProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _httpClient.BaseAddress = new Uri("https://inventaire.io/api/");
    }

    public async Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        try
        {
            var cleanIsbn = isbn.Replace("-", "").Replace(" ", "");
            var url = $"entities?action=by-uris&uris=isbn:{cleanIsbn}";
            var response = await _httpClient.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Inventaire returned {StatusCode} for ISBN {Isbn}", response.StatusCode, isbn);
                return null;
            }
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<InventaireResponse>(content, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (result?.Entities == null || result.Entities.Count == 0)
                return null;
            var entity = result.Entities.Values.FirstOrDefault();
            if (entity == null)
                return null;
            return MapToBook(entity, cleanIsbn);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching book from Inventaire for ISBN {Isbn}", isbn);
            return null;
        }
    }

    public async Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        var books = new List<Book>();
        try
        {
            var url = $"search?types=entity&search={Uri.EscapeDataString(searchText)}";
            var response = await _httpClient.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Inventaire returned {StatusCode} for text '{Text}'", response.StatusCode, searchText);
                return books;
            }
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<InventaireSearchResponse>(content, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (result?.Results == null) return books;
            foreach (var r in result.Results)
            {
                if (r.Entity != null)
                {
                    var book = MapToBook(r.Entity, null);
                    if (book != null) books.Add(book);
                }
            }
            return books;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching Inventaire for text '{Text}'", searchText);
            return books;
        }
    }

    private Book? MapToBook(InventaireEntity entity, string? isbn)
    {
        string? coverUrl = null;
        if (entity.Image != null)
        {
            // Inventaire returns relative URLs, prepend domain
            coverUrl = entity.Image.StartsWith("http") ? entity.Image : $"https://inventaire.io{entity.Image}";
        }
        return new Book
        {
            Title = entity.Label ?? "Unknown",
            Authors = entity.Authors ?? new List<string>(),
            Publisher = entity.Publisher,
            PublishYear = entity.Published != null ? ExtractYear(entity.Published) : null,
            PageCount = entity.PageCount,
            Description = entity.Description,
            Isbn = isbn ?? entity.Isbn,
            CoverImageUrl = coverUrl,
            Source = "Inventaire",
            ExternalId = entity.Uri
        };
    }

    private static int? ExtractYear(string? published)
    {
        if (string.IsNullOrEmpty(published)) return null;
        if (int.TryParse(published.Substring(0, Math.Min(4, published.Length)), out var year))
        {
            if (year >= 1000 && year <= DateTime.Now.Year + 1)
                return year;
        }
        return null;
    }

    // Inventaire API response models
    private class InventaireResponse
    {
        public Dictionary<string, InventaireEntity>? Entities { get; set; }
    }
    private class InventaireEntity
    {
        public string? Uri { get; set; }
        public string? Label { get; set; }
        public List<string>? Authors { get; set; }
        public string? Publisher { get; set; }
        public string? Published { get; set; }
        public int? PageCount { get; set; }
        public string? Description { get; set; }
        public string? Isbn { get; set; }
        public string? Image { get; set; }
    }
    private class InventaireSearchResponse
    {
        public List<InventaireSearchResult>? Results { get; set; }
    }
    private class InventaireSearchResult
    {
        public InventaireEntity? Entity { get; set; }
    }
}
