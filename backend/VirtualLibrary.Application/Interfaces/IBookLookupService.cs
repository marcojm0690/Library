using VirtualLibrary.Domain.Entities;

namespace VirtualLibrary.Application.Interfaces;

public interface IBookLookupService
{
    Task<Book?> LookupBookByISBNAsync(string isbn, CancellationToken cancellationToken = default);
}
