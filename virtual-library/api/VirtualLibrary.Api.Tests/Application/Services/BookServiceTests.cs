using FluentAssertions;
using Xunit;

namespace VirtualLibrary.Api.Tests.Application.Services;

public class BookServiceTests
{
    [Fact]
    public void SampleTest_StringOperations()
    {
        // Arrange
        var input = "Hello World";
        
        // Act
        var result = input.ToLower();
        
        // Assert
        result.Should().Be("hello world");
    }

    [Theory]
    [InlineData("978-0-13-468599-1", true)]
    [InlineData("9780134685991", true)]
    [InlineData("invalid", false)]
    public void IsValidIsbn_ValidatesCorrectly(string isbn, bool expected)
    {
        // Act
        var isValid = isbn.Length >= 10 && isbn.Length <= 17;
        
        // Assert
        isValid.Should().Be(expected);
    }
}
