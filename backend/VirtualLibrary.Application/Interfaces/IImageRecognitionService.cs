using VirtualLibrary.Domain.Entities;

namespace VirtualLibrary.Application.Interfaces;

public interface IImageRecognitionService
{
    Task<List<Book>> SearchBooksByCoverImageAsync(string imageBase64, CancellationToken cancellationToken = default);
}
