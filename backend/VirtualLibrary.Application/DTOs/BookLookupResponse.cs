namespace VirtualLibrary.Application.DTOs;

public class BookLookupResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public BookDto? Book { get; set; }
}
