using Microsoft.AspNetCore.Mvc;
using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.DTOs;
using VirtualLibrary.Api.Domain;
using VirtualLibrary.Api.Infrastructure.Cache;

namespace VirtualLibrary.Api.Controllers;

/// <summary>
/// Controller for library management operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class LibrariesController : ControllerBase
{
    private readonly ILibraryRepository _libraryRepository;
    private readonly RedisCacheService _cache;
    private readonly ILogger<LibrariesController> _logger;

    public LibrariesController(
        ILibraryRepository libraryRepository,
        RedisCacheService cache,
        ILogger<LibrariesController> logger)
    {
        _libraryRepository = libraryRepository;
        _cache = cache;
        _logger = logger;
    }

    /// <summary>
    /// Get all libraries
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<LibraryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<LibraryResponse>>> GetAll()
    {
        var libraries = await _libraryRepository.GetAllAsync();
        var responses = libraries.Select(MapToResponse);
        return Ok(responses);
    }

    /// <summary>
    /// Get a library by ID
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> GetById(Guid id)
    {
        var cacheKey = $"library:{id}";
        
        // Check cache first
        var cachedLibrary = await _cache.GetAsync<Library>(cacheKey);
        if (cachedLibrary != null)
        {
            _logger.LogInformation("Cache hit for library {LibraryId}", id);
            return Ok(MapToResponse(cachedLibrary));
        }
        
        _logger.LogInformation("Cache miss for library {LibraryId}", id);
        var library = await _libraryRepository.GetByIdAsync(id);
        
        if (library == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }
cacheKey = $"libraries:owner:{owner}";
        
        // Check cache first
        var cachedLibraries = await _cache.GetAsync<List<Library>>(cacheKey);
        if (cachedLibraries != null)
        {
            _logger.LogInformation("Cache hit for owner {Owner} libraries", owner);
            var cachedResponses = cachedLibraries.Select(MapToResponse);
            return Ok(cachedResponses);
        }
        
        _logger.LogInformation("Cache miss for owner {Owner} libraries", owner);
        var libraries = await _libraryRepository.GetByOwnerAsync(owner);
        var libraryList = libraries.ToList();
        
        // Cache for 3 minutes (shorter since this might change more frequently)
        await _cache.SetAsync(cacheKey, libraryList, TimeSpan.FromMinutes(3));
        
        var responses = libraryList5 minutes
        await _cache.SetAsync(cacheKey, library, TimeSpan.FromMinutes(5));
        
        return Ok(MapToResponse(library));
    }

    /// <summary>
    /// Get libraries by owner
    /// </summary>
    [HttpGet("owner/{owner}")]
    [ProducesResponseType(typeof(IEnumerable<LibraryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<LibraryResponse>>> GetByOwner(string owner)
    {
        var libraries = await _libraryRepository.GetByOwnerAsync(owner);
        var responses = libraries.Select(MapToResponse);
        return Ok(responses);
    }

    /// <summary>
    /// Create a new library
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LibraryResponse>> Create([FromBody] CreateLibraryRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new { message = "Library name is required" });
        }

        if (string.IsNullOrWhiteSpace(request.Owner))
        {
            return BadRequest(new { message = "Owner is required" });
        }

        var library = new Library
        {
            Name = request.Name,
            Description = request.Description,
            Owner = request.Owner,
            Tags = request.Tags ?? new List<string>(),
            IsPublic = request.IsPublic
        };

        var created = await _libraryRepository.CreateAsync(library);
        var response = MapToResponse(created);

        return CreatedAtAction(nameof(GetById), new { id = created.Id }, response);
    }

    /// <summary>
    /// Update a library
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> Update(Guid id, [FromBody] UpdateLibraryRequest request)
    {
        var existing = await _libraryRepository.GetByIdAsync(id);
        
        if (existing == null)
        // Invalidate caches
        await InvalidateLibraryCache(id, updated.Owner);
        
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Update only provided fields
        if (request.Name != null) existing.Name = request.Name;
        if (request.Description != null) existing.Description = request.Description;
        if (request.Tags != null) existing.Tags = request.Tags;
        if (request.IsPublic.HasValue) existing.IsPublic = request.IsPublic.Value;

        var updated = await _libraryRepository.UpdateAsync(existing);
        
        if (updated == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Delete a library
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [Pro// Get library first to invalidate owner cache
        var library = await _libraryRepository.GetByIdAsync(id);
        
        var deleted = await _libraryRepository.DeleteAsync(id);
        
        if (!deleted)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches
        if (library != null)
        {
            await InvalidateLibraryCache(id, library.Owner
        if (!deleted)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        return NoContent();
    }

    /// <summary>
    /// Add books to a library
    /// </summary>
    [Htt// Invalidate caches since book count changed
        await InvalidateLibraryCache(id, updated.Owner);

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Remove books from a library
    /// </summary>
    [HttpDelete("{id:guid}/books")]
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> RemoveBooks(Guid id, [FromBody] AddBooksToLibraryRequest request)
    {
        var updated = await _libraryRepository.RemoveBooksAsync(id, request.BookIds);
        
        if (updated == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        // Invalidate caches since book count changed
        await InvalidateLibraryCache(id, updated.Owner);

        return Ok(MapToResponse(updated));
    }

    /// <summary>
    /// Invalidate library cache when data changes
    /// </summary>
    private async Task InvalidateLibraryCache(Guid libraryId, string owner)
    {
        // Remove individual library cache
        await _cache.RemoveAsync($"library:{libraryId}");
        
        // Remove owner's libraries cache
        await _cache.RemoveAsync($"libraries:owner:{owner}");
        
        _logger.LogInformation("Invalidated cache for library {LibraryId} and owner {Owner}", libraryId, owner
    [ProducesResponseType(typeof(LibraryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LibraryResponse>> RemoveBooks(Guid id, [FromBody] AddBooksToLibraryRequest request)
    {
        var updated = await _libraryRepository.RemoveBooksAsync(id, request.BookIds);
        
        if (updated == null)
        {
            return NotFound(new { message = $"Library with ID {id} not found" });
        }

        return Ok(MapToResponse(updated));
    }

    private static LibraryResponse MapToResponse(Library library) => new()
    {
        Id = library.Id,
        Name = library.Name,
        Description = library.Description,
        Owner = library.Owner,
        CreatedAt = library.CreatedAt,
        UpdatedAt = library.UpdatedAt,
        BookIds = library.BookIds,
        BookCount = library.BookIds.Count,
        Tags = library.Tags,
        IsPublic = library.IsPublic
    };
}
