using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Infrastructure.External;

/// <summary>
/// Stub implementation for Open Library API integration.
/// Real implementation would use their REST API: https://openlibrary.org/dev/docs/api/books
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
        _logger.LogInformation("OpenLibrary: Searching for ISBN {Isbn}", isbn);
        
        // TODO: Implement actual API call
        // Example endpoint: GET /api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data
        
        // Stub implementation returns null
        // Real implementation would:
        // 1. Make HTTP request to Open Library API
        // 2. Parse JSON response
        // 3. Map to Book domain entity
        // 4. Handle errors and edge cases
        
        await Task.CompletedTask;
        return null;
    }

    public async Task<List<Book>> SearchByTextAsync(string searchText, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("OpenLibrary: Searching for text: {Text}", searchText);
        
        // TODO: Implement actual API call
        // Example endpoint: GET /search.json?q={searchText}&limit=10
        
        // Stub implementation returns empty list
        // Real implementation would:
        // 1. Make HTTP request to Open Library search API
        // 2. Parse JSON response with multiple results
        // 3. Map each result to Book domain entity
        // 4. Handle pagination if needed
        // 5. Handle errors and edge cases
        
        await Task.CompletedTask;
        return new List<Book>();
    }
}
