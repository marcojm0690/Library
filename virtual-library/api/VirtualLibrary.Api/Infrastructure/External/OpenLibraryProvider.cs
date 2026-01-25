using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Open Library API integration.
/// Documentation: https://openlibrary.org/dev/docs/api/search
/// </summary>
public class OpenLibraryProvider : IBookProvider
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<OpenLibraryProvider> _logger;

    public string ProviderName => "OpenLibrary";

    public OpenLibraryProvider(HttpClient httpClient, ILogger<OpenLibraryProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        
        // Configure base address for Open Library API
        _httpClient.BaseAddress = new Uri("https://openlibrary.org/");
    }

    public async Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("OpenLibrary: Searching for ISBN {Isbn}", isbn);
            
            var response = await _httpClient.GetAsync($"api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data", cancellationToken);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("OpenLibrary API returned {StatusCode}", response.StatusCode);
                return null;
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            var result = JsonSerializer.Deserialize<Dictionary<string, OpenLibraryBookData>>(content);

            if (result == null || !result.Any())
            {
                return null;
            }

            var bookData = result.First().Value;
            var book = MapToBook(bookData);
            
            // Fetch description from works endpoint if available
            if (book != null && !string.IsNullOrEmpty(bookData.Key))
            {
                var description = await FetchDescriptionFromWorkAsync(bookData.Key, cancellationToken);
                if (!string.IsNullOrEmpty(description))
                {
                    book.Description = description;
                }
            }
            
            return book;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching OpenLibrary for ISBN {Isbn}", isbn);
            return null;
        }
    }

    public async Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("OpenLibrary: Searching for text: {Text}", searchText);
            
            // Request specific fields including ISBN to ensure they're returned
            var fields = "key,title,author_name,publisher,first_publish_year,number_of_pages_median,isbn,cover_i,edition_count";
            var response = await _httpClient.GetAsync($"search.json?q={Uri.EscapeDataString(searchText)}&fields={fields}&limit=10", cancellationToken);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("OpenLibrary API returned {StatusCode}", response.StatusCode);
                return new List<Book>();
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogDebug("OpenLibrary search response: {Response}", content);
            
            var result = JsonSerializer.Deserialize<OpenLibrarySearchResponse>(content);

            if (result?.Docs == null || result.Docs.Count == 0)
            {
                _logger.LogInformation("OpenLibrary returned no results");
                return new List<Book>();
            }

            _logger.LogInformation("OpenLibrary returned {Count} results", result.Docs.Count);
            
            // Log ISBN availability for debugging
            var resultsWithIsbn = result.Docs.Count(d => d.Isbn != null && d.Isbn.Any());
            _logger.LogInformation("OpenLibrary: {Count} of {Total} results have ISBN", resultsWithIsbn, result.Docs.Count);
            
            return result.Docs.Select(MapToBook).Where(b => b != null).Cast<Book>().ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching OpenLibrary for text: {Text}", searchText);
            return new List<Book>();
        }
    }

    private Book? MapToBook(OpenLibraryBookData bookData)
    {
        if (string.IsNullOrEmpty(bookData.Title)) return null;

        return new Book
        {
            Id = Guid.NewGuid(),
            Title = bookData.Title,
            Authors = bookData.Authors?.Select(a => a.Name).ToList() ?? new List<string>(),
            Publisher = bookData.Publishers?.FirstOrDefault()?.Name,
            PublishYear = ExtractYear(bookData.PublishDate),
            Description = bookData.Subtitle,
            PageCount = bookData.NumberOfPages,
            Isbn = bookData.Identifiers?.Isbn13?.FirstOrDefault() ?? bookData.Identifiers?.Isbn10?.FirstOrDefault(),
            CoverImageUrl = bookData.Cover?.Large ?? bookData.Cover?.Medium ?? bookData.Cover?.Small,
            Source = ProviderName,
            ExternalId = bookData.Key
        };
    }

    private Book? MapToBook(OpenLibraryDoc doc)
    {
        if (string.IsNullOrEmpty(doc.Title)) return null;

        return new Book
        {
            Id = Guid.NewGuid(),
            Title = doc.Title,
            Authors = doc.AuthorName ?? new List<string>(),
            Publisher = doc.Publisher?.FirstOrDefault(),
            PublishYear = doc.FirstPublishYear,
            PageCount = doc.NumberOfPagesMedian,
            Isbn = doc.Isbn?.FirstOrDefault(),
            CoverImageUrl = doc.CoverI != null ? $"https://covers.openlibrary.org/b/id/{doc.CoverI}-L.jpg" : null,
            Source = ProviderName,
            ExternalId = doc.Key
        };
    }

    private int? ExtractYear(string? publishDate)
    {
        if (string.IsNullOrEmpty(publishDate)) return null;
        if (publishDate.Length >= 4 && int.TryParse(publishDate.Substring(0, 4), out int year))
        {
            return year;
        }
        return null;
    }

    /// <summary>
    /// Fetch description from OpenLibrary Works endpoint
    /// </summary>
    private async Task<string?> FetchDescriptionFromWorkAsync(string bookKey, CancellationToken cancellationToken)
    {
        try
        {
            // The book key might be like "/books/OL123M", we need to find the work key
            // First, get the book details to find the works
            var bookResponse = await _httpClient.GetAsync($"{bookKey}.json", cancellationToken);
            if (!bookResponse.IsSuccessStatusCode)
            {
                return null;
            }

            var bookContent = await bookResponse.Content.ReadAsStringAsync(cancellationToken);
            var bookDetails = JsonSerializer.Deserialize<OpenLibraryBookDetails>(bookContent);

            var workKey = bookDetails?.Works?.FirstOrDefault()?.Key;
            if (string.IsNullOrEmpty(workKey))
            {
                return null;
            }

            // Now fetch the work details which contain the description
            var workResponse = await _httpClient.GetAsync($"{workKey}.json", cancellationToken);
            if (!workResponse.IsSuccessStatusCode)
            {
                return null;
            }

            var workContent = await workResponse.Content.ReadAsStringAsync(cancellationToken);
            var workDetails = JsonSerializer.Deserialize<OpenLibraryWork>(workContent);

            // Description can be a string or an object with "value" property
            if (workDetails?.Description.HasValue == true)
            {
                var description = workDetails.Description.Value;
                
                if (description.ValueKind == JsonValueKind.String)
                {
                    return description.GetString();
                }
                else if (description.ValueKind == JsonValueKind.Object)
                {
                    if (description.TryGetProperty("value", out var valueElement))
                    {
                        return valueElement.GetString();
                    }
                }
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to fetch description for book {BookKey}", bookKey);
            return null;
        }
    }
}

// Open Library API response models for book data endpoint
public class OpenLibraryBookData
{
    [JsonPropertyName("title")]
    public string? Title { get; set; }

    [JsonPropertyName("subtitle")]
    public string? Subtitle { get; set; }

    [JsonPropertyName("authors")]
    public List<OpenLibraryAuthor>? Authors { get; set; }

    [JsonPropertyName("publishers")]
    public List<OpenLibraryPublisher>? Publishers { get; set; }

    [JsonPropertyName("publish_date")]
    public string? PublishDate { get; set; }

    [JsonPropertyName("number_of_pages")]
    public int? NumberOfPages { get; set; }

    [JsonPropertyName("identifiers")]
    public OpenLibraryIdentifiers? Identifiers { get; set; }

    [JsonPropertyName("cover")]
    public OpenLibraryCover? Cover { get; set; }

    [JsonPropertyName("key")]
    public string? Key { get; set; }
}

public class OpenLibraryAuthor
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
}

public class OpenLibraryPublisher
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
}

public class OpenLibraryIdentifiers
{
    [JsonPropertyName("isbn_13")]
    public List<string>? Isbn13 { get; set; }

    [JsonPropertyName("isbn_10")]
    public List<string>? Isbn10 { get; set; }
}

public class OpenLibraryCover
{
    [JsonPropertyName("small")]
    public string? Small { get; set; }

    [JsonPropertyName("medium")]
    public string? Medium { get; set; }

    [JsonPropertyName("large")]
    public string? Large { get; set; }
}

// Open Library search endpoint response models
public class OpenLibrarySearchResponse
{
    [JsonPropertyName("docs")]
    public List<OpenLibraryDoc>? Docs { get; set; }
}

public class OpenLibraryDoc
{
    [JsonPropertyName("key")]
    public string? Key { get; set; }

    [JsonPropertyName("title")]
    public string? Title { get; set; }

    [JsonPropertyName("author_name")]
    public List<string>? AuthorName { get; set; }

    [JsonPropertyName("publisher")]
    public List<string>? Publisher { get; set; }

    [JsonPropertyName("first_publish_year")]
    public int? FirstPublishYear { get; set; }

    [JsonPropertyName("number_of_pages_median")]
    public int? NumberOfPagesMedian { get; set; }

    [JsonPropertyName("isbn")]
    public List<string>? Isbn { get; set; }

    [JsonPropertyName("cover_i")]
    public int? CoverI { get; set; }
}

// Models for fetching descriptions from Works API
public class OpenLibraryBookDetails
{
    [JsonPropertyName("works")]
    public List<OpenLibraryWorkReference>? Works { get; set; }
}

public class OpenLibraryWorkReference
{
    [JsonPropertyName("key")]
    public string? Key { get; set; }
}

public class OpenLibraryWork
{
    [JsonPropertyName("description")]
    public JsonElement? Description { get; set; }
}
