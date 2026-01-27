using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace VirtualLibrary.Api.Infrastructure;

public interface ITranslatorService
{
    Task<string> TranslateToEnglishAsync(string text, CancellationToken cancellationToken = default);
}

public class AzureTranslatorService : ITranslatorService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AzureTranslatorService> _logger;
    private readonly string _endpoint;
    private readonly string _key;
    private readonly string _region;

    public AzureTranslatorService(
        HttpClient httpClient, 
        IConfiguration configuration,
        ILogger<AzureTranslatorService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
        
        _endpoint = configuration["Azure:Translator:Endpoint"] ?? "https://api.cognitive.microsofttranslator.com";
        _key = configuration["Azure:Translator:Key"] ?? throw new InvalidOperationException("Azure Translator key not configured");
        _region = configuration["Azure:Translator:Region"] ?? "global";
    }

    public async Task<string> TranslateToEnglishAsync(string text, CancellationToken cancellationToken = default)
    {
        // If text is already likely English or very short, skip translation
        if (string.IsNullOrWhiteSpace(text) || text.Length < 3)
        {
            return text;
        }

        try
        {
            var route = "/translate?api-version=3.0&to=en";
            var body = new object[] { new { Text = text } };
            var requestBody = JsonSerializer.Serialize(body);

            using var request = new HttpRequestMessage
            {
                Method = HttpMethod.Post,
                RequestUri = new Uri(_endpoint + route),
                Content = new StringContent(requestBody, Encoding.UTF8, "application/json")
            };

            request.Headers.Add("Ocp-Apim-Subscription-Key", _key);
            request.Headers.Add("Ocp-Apim-Subscription-Region", _region);

            var response = await _httpClient.SendAsync(request, cancellationToken);
            response.EnsureSuccessStatusCode();

            var result = await response.Content.ReadAsStringAsync(cancellationToken);
            
            // Parse the response
            var translationResults = JsonSerializer.Deserialize<TranslationResult[]>(result);
            
            if (translationResults != null && translationResults.Length > 0 && 
                translationResults[0].Translations != null && translationResults[0].Translations.Length > 0)
            {
                var translatedText = translationResults[0].Translations[0].Text;
                
                // Log detected language for debugging
                var detectedLanguage = translationResults[0].DetectedLanguage?.Language ?? "unknown";
                if (detectedLanguage != "en")
                {
                    _logger.LogInformation("Translated '{Original}' ({Language}) to '{Translated}'", 
                        text, detectedLanguage, translatedText);
                }
                
                return translatedText;
            }
            
            _logger.LogWarning("Translation API returned empty result for '{Text}'", text);
            return text; // Fallback to original
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to translate '{Text}', using original", text);
            return text; // Fallback to original text on error
        }
    }

    // Response models
    private class TranslationResult
    {
        public DetectedLanguage? DetectedLanguage { get; set; }
        public Translation[]? Translations { get; set; }
    }

    private class DetectedLanguage
    {
        public string? Language { get; set; }
        public float Score { get; set; }
    }

    private class Translation
    {
        public string Text { get; set; } = string.Empty;
        public string To { get; set; } = string.Empty;
    }
}
