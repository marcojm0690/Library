using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.Books.SearchByIsbn;
using VirtualLibrary.Api.Application.Books.SearchByCover;
using VirtualLibrary.Api.Application.Books.SearchByImage;
using VirtualLibrary.Api.Infrastructure.External;
using VirtualLibrary.Api.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register application services
builder.Services.AddScoped<SearchByIsbnService>();
builder.Services.AddScoped<SearchByCoverService>();
builder.Services.AddScoped<SearchByImageService>();

// Register Azure services
builder.Services.AddScoped<AzureVisionProvider>();
builder.Services.AddScoped<AzureBlobLibraryRepository>();

// In-memory repository placeholder - replace with actual database implementation
builder.Services.AddSingleton<IBookRepository, InMemoryBookRepository>();

// Register external book provider services
builder.Services.AddHttpClient<IBookProvider, OpenLibraryProvider>();
builder.Services.AddHttpClient<IBookProvider, GoogleBooksProvider>();

// Configure CORS for iOS app
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwagger();
app.UseSwaggerUI();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors();
app.UseAuthorization();
app.MapControllers();

app.Run();
