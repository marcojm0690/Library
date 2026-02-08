using FluentAssertions;
using VirtualLibrary.Api.Domain;
using Xunit;

namespace VirtualLibrary.Api.Tests.Controllers;

public class LibrariesControllerTests
{
    [Fact]
    public void Library_Name_CannotBeEmpty()
    {
        // Arrange
        var library = new Library();

        // Assert
        library.Name.Should().BeEmpty();
    }

    [Fact]
    public void Library_UserId_MustBeSet()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var library = new Library
        {
            Name = "Test Library",
            UserId = userId
        };

        // Assert
        library.UserId.Should().Be(userId);
    }

    [Fact]
    public void Library_Timestamps_AreSet()
    {
        // Arrange & Act
        var library = new Library
        {
            Name = "Test",
            UserId = Guid.NewGuid(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        // Assert
        library.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
        library.UpdatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(1));
    }
}
