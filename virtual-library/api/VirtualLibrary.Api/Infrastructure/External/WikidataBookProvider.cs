using System.Text.Json;
using System.Web;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Book provider that uses Wikidata SPARQL endpoint
/// Completely free, no API key needed
/// Good for cover images via Wikimedia Commons
/// </summary>
public class WikidataBookProvider : IBookProvider
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<WikidataBookProvider> _logger;

    public string ProviderName => "Wikidata";

    public WikidataBookProvider(
        HttpClient httpClient,
        ILogger<WikidataBookProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _httpClient.BaseAddress = new Uri("https://www.wikidata.org/");
    }

    public async Task<Book?> SearchByIsbnAsync(string isbn, CancellationToken cancellationToken = default)
    {
        try
        {
            var cleanIsbn = isbn.Replace("-", "").Replace(" ", "");
            
            // SPARQL query to find book by ISBN and get cover image, description, etc.
            var sparqlQuery = $@"
                SELECT ?item ?itemLabel ?authorLabel ?publisherLabel ?publicationDate ?pages ?coverImage ?description WHERE {{
                  ?item wdt:P212 '{cleanIsbn}' .  # ISBN-13
                  OPTIONAL {{ ?item wdt:P50 ?author . }}
                  OPTIONAL {{ ?item wdt:P123 ?publisher . }}
                  OPTIONAL {{ ?item wdt:P577 ?publicationDate . }}
                  OPTIONAL {{ ?item wdt:P1104 ?pages . }}
                  OPTIONAL {{ ?item wdt:P18 ?coverImage . }}  # Image property
                  OPTIONAL {{ ?item schema:description ?description . FILTER(LANG(?description) = 'en') }}
                  SERVICE wikibase:label {{ bd:serviceParam wikibase:language 'en,es,de,fr'. }}
                }}
                LIMIT 1
            ";

            var encodedQuery = HttpUtility.UrlEncode(sparqlQuery);
            var url = $"sparql?query={encodedQuery}&format=json";

            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Wikidata returned {StatusCode} for ISBN {Isbn}", response.StatusCode, isbn);
                return null;
            }

            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<WikidataSparqlResponse>(content, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (result?.Results?.Bindings == null || result.Results.Bindings.Count == 0)
            {
                return null;
            }

            var binding = result.Results.Bindings[0];
            
            var title = binding.ItemLabel?.Value ?? "Unknown";
            var authors = new List<string>();
            if (!string.IsNullOrEmpty(binding.AuthorLabel?.Value))
            {
                authors.Add(binding.AuthorLabel.Value);
            }

            int? publishYear = null;
            if (!string.IsNullOrEmpty(binding.PublicationDate?.Value))
            {
                publishYear = ExtractYear(binding.PublicationDate.Value);
            }

            int? pageCount = null;
            if (!string.IsNullOrEmpty(binding.Pages?.Value) && int.TryParse(binding.Pages.Value, out var pages))
            {
                pageCount = pages;
            }

            // Convert Wikimedia Commons image URL to direct image URL
            string? coverUrl = null;
            if (!string.IsNullOrEmpty(binding.CoverImage?.Value))
            {
                coverUrl = await GetWikimediaImageUrlAsync(binding.CoverImage.Value);
            }

            return new Book
            {
                Title = title,
                Authors = authors,
                Publisher = binding.PublisherLabel?.Value,
                PublishYear = publishYear,
                PageCount = pageCount,
                Description = binding.Description?.Value,
                Isbn = cleanIsbn,
                CoverImageUrl = coverUrl,
                Source = "Wikidata",
                ExternalId = binding.Item?.Value
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching book from Wikidata for ISBN {Isbn}", isbn);
            return null;
        }
    }

    public Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        // Not implementing text search for now
        return Task.FromResult(new List<Book>());
    }

    private async Task<string?> GetWikimediaImageUrlAsync(string commonsUrl)
    {
        try
        {
            // Extract filename from Commons URL
            var filename = commonsUrl.Split('/').Last();
            
            // Use Wikimedia Commons API to get direct image URL
            var apiUrl = $"https://commons.wikimedia.org/w/api.php?action=query&titles=File:{filename}&prop=imageinfo&iiprop=url&format=json";
            
            var response = await _httpClient.GetAsync(apiUrl);
            if (!response.IsSuccessStatusCode)
                return null;

            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<WikimediaApiResponse>(content);

            var pages = result?.Query?.Pages;
            if (pages == null) return null;

            var page = pages.Values.FirstOrDefault();
            return page?.Imageinfo?.FirstOrDefault()?.Url;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get Wikimedia image URL from {Url}", commonsUrl);
            return null;
        }
    }

    private static int? ExtractYear(string date)
    {
        if (string.IsNullOrEmpty(date))
            return null;

        if (int.TryParse(date.Substring(0, Math.Min(4, date.Length)), out var year))
        {
            if (year >= 1000 && year <= DateTime.Now.Year + 1)
                return year;
        }

        return null;
    }

    // Wikidata SPARQL response models
    private class WikidataSparqlResponse
    {
        public WikidataResults? Results { get; set; }
    }

    private class WikidataResults
    {
        public List<WikidataBinding>? Bindings { get; set; }
    }

    private class WikidataBinding
    {
        public WikidataValue? Item { get; set; }
        public WikidataValue? ItemLabel { get; set; }
        public WikidataValue? AuthorLabel { get; set; }
        public WikidataValue? PublisherLabel { get; set; }
        public WikidataValue? PublicationDate { get; set; }
        public WikidataValue? Pages { get; set; }
        public WikidataValue? CoverImage { get; set; }
        public WikidataValue? Description { get; set; }
    }

    private class WikidataValue
    {
        public string? Value { get; set; }
    }

    // Wikimedia Commons API response models
    private class WikimediaApiResponse
    {
        public WikimediaQuery? Query { get; set; }
    }

    private class WikimediaQuery
    {
        public Dictionary<string, WikimediaPage>? Pages { get; set; }
    }

    private class WikimediaPage
    {
        public List<WikimediaImageInfo>? Imageinfo { get; set; }
    }

    private class WikimediaImageInfo
    {
        public string? Url { get; set; }
    }
}
