using FluentAssertions;
using VirtualLibrary.Api.Domain;
using Xunit;

namespace VirtualLibrary.Api.Tests.Domain;

public class LibraryTests
{
    [Fact]
    public void Library_Initialization_SetsProperties()
    {
        // Arrange & Act
        var library = new Library
        {
            Id = Guid.NewGuid(),
            Name = "My Library",
            Description = "Test Description",
            Owner = "test@example.com",
            UserId = Guid.NewGuid()
        };

        // Assert
        library.Name.Should().Be("My Library");
        library.Description.Should().Be("Test Description");
        library.Owner.Should().Be("test@example.com");
        library.BookIds.Should().BeEmpty();
    }

    [Fact]
    public void Library_CanAddBookIds()
    {
        // Arrange
        var library = new Library
        {
            Id = Guid.NewGuid(),
            Name = "Test Library",
            Owner = "test@example.com",
            UserId = Guid.NewGuid()
        };

        var bookId = Guid.NewGuid();

        // Act
        library.BookIds.Add(bookId);

        // Assert
        library.BookIds.Should().HaveCount(1);
        library.BookIds.First().Should().Be(bookId);
    }

    [Fact]
    public void Library_Tags_CanBeModified()
    {
        // Arrange
        var library = new Library
        {
            Id = Guid.NewGuid(),
            Name = "Test",
            UserId = Guid.NewGuid()
        };

        // Act
        library.Tags.Add("fiction");
        library.Tags.Add("classics");

        // Assert
        library.Tags.Should().HaveCount(2);
    }
}
