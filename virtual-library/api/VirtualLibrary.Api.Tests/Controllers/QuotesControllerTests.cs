using FluentAssertions;
using VirtualLibrary.Api.Controllers;
using Xunit;

namespace VirtualLibrary.Api.Tests.Controllers;

public class QuotesControllerTests
{
    [Theory]
    [InlineData("This is a test quote", "test quote", true)]
    [InlineData("A complete sentence.", "complete", true)]
    [InlineData("No match here", "xyz", false)]
    public void QuoteMatching_FindsSubstrings(string text, string search, bool shouldMatch)
    {
        // Act
        var contains = text.Contains(search, StringComparison.OrdinalIgnoreCase);
        
        // Assert
        contains.Should().Be(shouldMatch);
    }

    [Theory]
    [InlineData("quote text", "John Doe", "text")]
    [InlineData("test", "author", "text")]
    [InlineData("voice input", "speaker", "voice")]
    public void QuoteRequest_Construction_SetsProperties(string quote, string author, string method)
    {
        // Act
        var request = new QuoteVerificationRequest
        {
            QuoteText = quote,
            ClaimedAuthor = author,
            InputMethod = method
        };

        // Assert
        request.QuoteText.Should().Be(quote);
        request.ClaimedAuthor.Should().Be(author);
        request.InputMethod.Should().Be(method);
    }

    [Fact]
    public void QuoteResponse_Initialization_HasDefaultValues()
    {
        // Act
        var response = new QuoteVerificationResponse
        {
            OriginalQuote = "test",
            InputMethod = "text"
        };

        // Assert
        response.OriginalQuote.Should().Be("test");
        response.PossibleSources.Should().NotBeNull();
    }
}
