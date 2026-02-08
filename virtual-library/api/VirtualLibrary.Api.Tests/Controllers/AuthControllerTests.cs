using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using System.Security.Claims;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Controllers;
using VirtualLibrary.Api.Domain;
using Xunit;

namespace VirtualLibrary.Api.Tests.Controllers;

public class AuthControllerTests
{
    private readonly Mock<IUserRepository> _userRepositoryMock;
    private readonly Mock<IConfiguration> _configurationMock;
    private readonly Mock<IHttpClientFactory> _httpClientFactoryMock;
    private readonly Mock<ILogger<AuthController>> _loggerMock;
    private readonly AuthController _controller;

    public AuthControllerTests()
    {
        _userRepositoryMock = new Mock<IUserRepository>();
        _configurationMock = new Mock<IConfiguration>();
        _httpClientFactoryMock = new Mock<IHttpClientFactory>();
        _loggerMock = new Mock<ILogger<AuthController>>();
        
        // Setup configuration
        _configurationMock.Setup(x => x["OAuth:Microsoft:ClientId"]).Returns("test-client-id");
        _configurationMock.Setup(x => x["OAuth:Microsoft:RedirectUri"]).Returns("http://test.com/callback");
        _configurationMock.Setup(x => x["Jwt:SecretKey"]).Returns("test-secret-key-at-least-32-characters-long");
        _configurationMock.Setup(x => x["Jwt:Issuer"]).Returns("test-issuer");
        _configurationMock.Setup(x => x["Jwt:Audience"]).Returns("test-audience");
        _configurationMock.Setup(x => x["Jwt:ExpirationDays"]).Returns("30");

        _controller = new AuthController(
            _userRepositoryMock.Object,
            _configurationMock.Object,
            _httpClientFactoryMock.Object,
            _loggerMock.Object
        );
    }

    [Fact]
    public void GetConfig_ReturnsOAuthConfiguration()
    {
        // Act
        var result = _controller.GetConfig();

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        okResult!.Value.Should().NotBeNull();
    }

    [Fact]
    public async Task GetCurrentUser_WithoutAuthentication_ReturnsUnauthorized()
    {
        // Arrange
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext()
        };

        // Act
        var result = await _controller.GetCurrentUser();

        // Assert
        result.Should().BeOfType<UnauthorizedResult>();
    }

    [Fact]
    public async Task GetCurrentUser_WithValidUser_ReturnsUserInfo()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var user = new User
        {
            Id = userId,
            Email = "test@example.com",
            DisplayName = "Test User",
            ProfilePictureUrl = "https://example.com/photo.jpg"
        };

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString())
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var claimsPrincipal = new ClaimsPrincipal(identity);

        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = claimsPrincipal }
        };

        _userRepositoryMock.Setup(x => x.GetByIdAsync(userId))
            .ReturnsAsync(user);

        // Act
        var result = await _controller.GetCurrentUser();

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        okResult!.Value.Should().NotBeNull();
    }
}
