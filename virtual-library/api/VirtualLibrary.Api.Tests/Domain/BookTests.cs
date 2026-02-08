using FluentAssertions;
using VirtualLibrary.Api.Domain;
using Xunit;

namespace VirtualLibrary.Api.Tests.Domain;

public class BookTests
{
    [Fact]
    public void Book_Initialization_SetsProperties()
    {
        // Arrange & Act
        var book = new Book
        {
            Isbn = "9780134685991",
            Title = "Effective Java",
            Authors = new List<string> { "Joshua Bloch" },
            Publisher = "Addison-Wesley",
            PublishYear = 2018
        };

        // Assert
        book.Isbn.Should().Be("9780134685991");
        book.Title.Should().Be("Effective Java");
        book.Authors.Should().Contain("Joshua Bloch");
        book.Publisher.Should().Be("Addison-Wesley");
        book.PublishYear.Should().Be(2018);
    }

    [Theory]
    [InlineData("9780134685991")]
    [InlineData("978-0-13-468599-1")]
    public void Book_IsbnVariations_AreValid(string isbn)
    {
        // Act
        var book = new Book { Isbn = isbn, Title = "Test" };

        // Assert
        book.Isbn.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public void Book_Authors_CanBeEmpty()
    {
        // Act
        var book = new Book { Title = "Test Book", Isbn = "123" };

        // Assert
        book.Authors.Should().BeEmpty();
    }
}
