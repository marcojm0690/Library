namespace VirtualLibrary.Application.DTOs;

public class SearchByCoverResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public List<BookDto> Books { get; set; } = new();
}
