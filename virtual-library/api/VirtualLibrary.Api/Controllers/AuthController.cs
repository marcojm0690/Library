using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Domain;

namespace VirtualLibrary.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IUserRepository _userRepository;
    private readonly IConfiguration _configuration;
    private readonly HttpClient _httpClient;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        IUserRepository userRepository,
        IConfiguration configuration,
        IHttpClientFactory httpClientFactory,
        ILogger<AuthController> logger)
    {
        _userRepository = userRepository;
        _configuration = configuration;
        _httpClient = httpClientFactory.CreateClient();
        _logger = logger;
    }

    /// <summary>
    /// Get OAuth configuration for the mobile app
    /// </summary>
    [HttpGet("config")]
    public IActionResult GetConfig()
    {
        var config = new
        {
            microsoft = new
            {
                clientId = _configuration["OAuth:Microsoft:ClientId"],
                redirectUri = _configuration["OAuth:Microsoft:RedirectUri"],
                authorizeUrl = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                scope = "openid profile email User.Read"
            }
        };

        return Ok(config);
    }

    /// <summary>
    /// Exchange authorization code for JWT token
    /// </summary>
    [HttpPost("oauth/microsoft")]
    public async Task<IActionResult> MicrosoftOAuth([FromBody] OAuthRequest request)
    {
        try
        {
            // Exchange authorization code for access token
            var tokenResponse = await ExchangeCodeForTokenAsync(request.Code);
            if (tokenResponse == null)
            {
                return BadRequest(new { error = "Failed to exchange authorization code" });
            }

            // Get user info from Microsoft Graph
            var userInfo = await GetMicrosoftUserInfoAsync(tokenResponse.AccessToken);
            if (userInfo == null)
            {
                return BadRequest(new { error = "Failed to get user information" });
            }

            // Find or create user
            var user = await _userRepository.GetByExternalIdAsync(userInfo.Id, "microsoft");
            if (user == null)
            {
                user = new User
                {
                    ExternalId = userInfo.Id,
                    Provider = "microsoft",
                    Email = userInfo.Mail ?? userInfo.UserPrincipalName ?? "",
                    DisplayName = userInfo.DisplayName,
                    ProfilePictureUrl = null // Could fetch from Graph API
                };
                user = await _userRepository.CreateAsync(user);
            }
            else
            {
                // Update last login
                user.LastLoginAt = DateTime.UtcNow;
                await _userRepository.UpdateAsync(user);
            }

            // Generate JWT token
            var jwtToken = GenerateJwtToken(user);

            return Ok(new
            {
                token = jwtToken,
                user = new
                {
                    id = user.Id,
                    email = user.Email,
                    displayName = user.DisplayName,
                    profilePictureUrl = user.ProfilePictureUrl
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during Microsoft OAuth");
            return StatusCode(500, new { error = "Internal server error" });
        }
    }

    /// <summary>
    /// Get current user information (requires authentication)
    /// </summary>
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized();
        }

        var user = await _userRepository.GetByIdAsync(userId);
        if (user == null)
        {
            return NotFound();
        }

        return Ok(new
        {
            id = user.Id,
            email = user.Email,
            displayName = user.DisplayName,
            profilePictureUrl = user.ProfilePictureUrl
        });
    }

    /// <summary>
    /// Mobile OAuth callback - handles Microsoft redirect and deep-links back to iOS app
    /// </summary>
    [HttpGet("callback/microsoft/mobile")]
    public async Task<IActionResult> MicrosoftMobileCallback([FromQuery] string code, [FromQuery] string? state)
    {
        try
        {
            if (string.IsNullOrEmpty(code))
            {
                return Redirect("virtuallibrary://oauth-complete?error=no_code");
            }

            // Exchange authorization code for access token - use the exact mobile redirect URI
            // This MUST match exactly what the iOS app sent in the authorization request
            var mobileRedirectUri = "https://virtual-library-api-web.azurewebsites.net/api/auth/callback/microsoft/mobile";
            
            _logger.LogInformation("Mobile OAuth callback - using redirect URI: {RedirectUri}", mobileRedirectUri);
            
            var tokenResponse = await ExchangeCodeForTokenAsync(code, mobileRedirectUri);
            if (tokenResponse == null)
            {
                return Redirect("virtuallibrary://oauth-complete?error=token_exchange_failed");
            }

            // Get user info from Microsoft Graph
            var userInfo = await GetMicrosoftUserInfoAsync(tokenResponse.AccessToken);
            if (userInfo == null)
            {
                return Redirect("virtuallibrary://oauth-complete?error=user_info_failed");
            }

            // Find or create user
            var user = await _userRepository.GetByExternalIdAsync(userInfo.Id, "microsoft");
            if (user == null)
            {
                user = new User
                {
                    ExternalId = userInfo.Id,
                    Provider = "microsoft",
                    Email = userInfo.Mail ?? userInfo.UserPrincipalName ?? "",
                    DisplayName = userInfo.DisplayName,
                    ProfilePictureUrl = null
                };
                user = await _userRepository.CreateAsync(user);
            }
            else
            {
                user.LastLoginAt = DateTime.UtcNow;
                await _userRepository.UpdateAsync(user);
            }

            // Generate JWT token
            var jwtToken = GenerateJwtToken(user);

            // Redirect back to iOS app with token
            return Redirect($"virtuallibrary://oauth-complete?token={Uri.EscapeDataString(jwtToken)}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during mobile Microsoft OAuth callback");
            return Redirect("virtuallibrary://oauth-complete?error=internal_error");
        }
    }

    private async Task<TokenResponse?> ExchangeCodeForTokenAsync(string code, string? overrideRedirectUri = null)
    {
        var clientId = _configuration["OAuth:Microsoft:ClientId"];
        var clientSecret = _configuration["OAuth:Microsoft:ClientSecret"];
        var redirectUri = overrideRedirectUri ?? _configuration["OAuth:Microsoft:RedirectUri"];

        var tokenEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token";
        var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["client_id"] = clientId!,
            ["client_secret"] = clientSecret!,
            ["code"] = code,
            ["redirect_uri"] = redirectUri!,
            ["grant_type"] = "authorization_code"
        });

        _logger.LogInformation("Exchanging code for token with redirect_uri: {RedirectUri}", redirectUri);

        var response = await _httpClient.PostAsync(tokenEndpoint, content);
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            _logger.LogError("Token exchange failed: {Error}", error);
            return null;
        }

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TokenResponse>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
    }

    private async Task<MicrosoftUserInfo?> GetMicrosoftUserInfoAsync(string accessToken)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "https://graph.microsoft.com/v1.0/me");
        request.Headers.Add("Authorization", $"Bearer {accessToken}");

        var response = await _httpClient.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            _logger.LogError("Failed to get user info: {Error}", error);
            return null;
        }

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<MicrosoftUserInfo>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
    }

    private string GenerateJwtToken(User user)
    {
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Jwt:SecretKey"]!));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Name, user.DisplayName ?? user.Email),
            new Claim("provider", user.Provider)
        };

        var expirationDays = int.Parse(_configuration["Jwt:ExpirationDays"] ?? "30");
        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddDays(expirationDays),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public class OAuthRequest
    {
        public string Code { get; set; } = string.Empty;
    }

    private class TokenResponse
    {
        public string AccessToken { get; set; } = string.Empty;
    }

    private class MicrosoftUserInfo
    {
        public string Id { get; set; } = string.Empty;
        public string? DisplayName { get; set; }
        public string? Mail { get; set; }
        public string? UserPrincipalName { get; set; }
    }
}
