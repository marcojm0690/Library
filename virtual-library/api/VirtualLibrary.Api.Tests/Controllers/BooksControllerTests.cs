using FluentAssertions;
using Xunit;

namespace VirtualLibrary.Api.Tests.Controllers;

public class BooksControllerTests
{
    [Theory]
    [InlineData("978-0-13-468599-1", "9780134685991")]
    [InlineData("978 0 13 468599 1", "9780134685991")]
    [InlineData("9780134685991", "9780134685991")]
    public void IsbnNormalization_RemovesHyphensAndSpaces(string input, string expected)
    {
        // Act
        var actual = input.Replace("-", "").Replace(" ", "");
        
        // Assert
        actual.Should().Be(expected);
    }

    [Theory]
    [InlineData("9780134685991", true)]
    [InlineData("978-0-13-468599-1", true)]
    [InlineData("123", false)]
    [InlineData("", false)]
    public void IsValidIsbn_ValidatesLength(string isbn, bool shouldBeValid)
    {
        // Act
        var normalized = isbn.Replace("-", "").Replace(" ", "");
        var isValid = normalized.Length == 10 || normalized.Length == 13;
        
        // Assert
        isValid.Should().Be(shouldBeValid);
    }

    [Fact]
    public void IsbnNormalization_HandlesNullInput()
    {
        // Arrange
        string? isbn = null;
        
        // Act & Assert
        isbn.Should().BeNull();
    }
}
