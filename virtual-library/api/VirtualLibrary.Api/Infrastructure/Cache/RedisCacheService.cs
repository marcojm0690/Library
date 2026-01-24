using StackExchange.Redis;
using System.Text.Json;

namespace VirtualLibrary.Api.Infrastructure.Cache;

/// <summary>
/// Redis cache service for caching API responses
/// </summary>
public class RedisCacheService
{
    private readonly IConnectionMultiplexer? _redis;
    private readonly IDatabase? _cache;
    private readonly ILogger<RedisCacheService> _logger;
    private readonly TimeSpan _defaultExpiration;
    private readonly bool _isEnabled;

    public RedisCacheService(
        IConfiguration configuration,
        ILogger<RedisCacheService> logger)
    {
        _logger = logger;
        
        var connectionString = configuration["Azure:Redis:ConnectionString"];
        var expirationMinutes = configuration.GetValue<int>("Azure:Redis:CacheExpirationMinutes", 1440);
        _defaultExpiration = TimeSpan.FromMinutes(expirationMinutes);

        if (string.IsNullOrEmpty(connectionString))
        {
            _logger.LogWarning("Redis connection string not configured. Caching disabled.");
            _isEnabled = false;
            return;
        }

        try
        {
            _redis = ConnectionMultiplexer.Connect(connectionString);
            _cache = _redis.GetDatabase();
            _isEnabled = true;
            _logger.LogInformation("Redis cache initialized successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to Redis. Caching disabled.");
            _isEnabled = false;
        }
    }

    /// <summary>
    /// Get cached value by key
    /// </summary>
    public async Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
    {
        if (!_isEnabled || _cache == null) return default;

        try
        {
            var value = await _cache.StringGetAsync(key);
            
            if (value.IsNullOrEmpty)
            {
                _logger.LogDebug("Cache miss for key: {Key}", key);
                return default;
            }

            _logger.LogDebug("Cache hit for key: {Key}", key);
            return JsonSerializer.Deserialize<T>(value.ToString());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error reading from cache for key: {Key}", key);
            return default;
        }
    }

    /// <summary>
    /// Set cached value with default expiration
    /// </summary>
    public async Task SetAsync<T>(string key, T value, CancellationToken cancellationToken = default)
    {
        await SetAsync(key, value, _defaultExpiration, cancellationToken);
    }

    /// <summary>
    /// Set cached value with custom expiration
    /// </summary>
    public async Task SetAsync<T>(string key, T value, TimeSpan expiration, CancellationToken cancellationToken = default)
    {
        if (!_isEnabled || _cache == null) return;

        try
        {
            var json = JsonSerializer.Serialize(value);
            await _cache.StringSetAsync(key, json, expiration);
            _logger.LogDebug("Cached value for key: {Key} (expires in {Minutes} minutes)", key, expiration.TotalMinutes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error writing to cache for key: {Key}", key);
        }
    }

    /// <summary>
    /// Remove cached value
    /// </summary>
    public async Task RemoveAsync(string key, CancellationToken cancellationToken = default)
    {
        if (!_isEnabled || _cache == null) return;

        try
        {
            await _cache.KeyDeleteAsync(key);
            _logger.LogDebug("Removed cache key: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing cache key: {Key}", key);
        }
    }

    /// <summary>
    /// Check if caching is enabled
    /// </summary>
    public bool IsEnabled => _isEnabled;
}
