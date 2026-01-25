using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.Books.SearchByIsbn;
using VirtualLibrary.Api.Application.Books.SearchByCover;
using VirtualLibrary.Api.Application.Books.SearchByImage;
using VirtualLibrary.Api.Infrastructure.External;
using VirtualLibrary.Api.Infrastructure.Persistence;
using VirtualLibrary.Api.Infrastructure.Cache;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register Redis cache service
builder.Services.AddSingleton<RedisCacheService>();

// Register application services
builder.Services.AddScoped<SearchByIsbnService>();
builder.Services.AddScoped<SearchByCoverService>();
builder.Services.AddScoped<SearchByImageService>();

// Register Azure services
builder.Services.AddScoped<AzureVisionProvider>();
builder.Services.AddScoped<AzureBlobLibraryRepository>();

// Register MongoDB/Cosmos DB repository
var mongoDbConfig = builder.Configuration.GetSection("Azure:MongoDB");
var connectionString = mongoDbConfig["ConnectionString"];
var databaseName = mongoDbConfig["DatabaseName"] ?? "LibraryDb";
var collectionName = mongoDbConfig["CollectionName"] ?? "Books";
var librariesCollectionName = mongoDbConfig["LibrariesCollectionName"] ?? "Libraries";

if (!string.IsNullOrEmpty(connectionString))
{
    // Use MongoDB repository for production
    builder.Services.AddScoped<MongoDbBookRepository>(sp =>
        new MongoDbBookRepository(
            connectionString,
            databaseName,
            collectionName,
            sp.GetRequiredService<ILogger<MongoDbBookRepository>>()));

    builder.Services.AddScoped<IBookRepository>(sp =>
        sp.GetRequiredService<MongoDbBookRepository>());

    // Register library repository
    builder.Services.AddScoped<MongoDbLibraryRepository>(sp =>
        new MongoDbLibraryRepository(
            connectionString,
            databaseName,
            librariesCollectionName,
            sp.GetRequiredService<ILogger<MongoDbLibraryRepository>>()));

    builder.Services.AddScoped<ILibraryRepository>(sp =>
        sp.GetRequiredService<MongoDbLibraryRepository>());

    // Register seeder for development/testing
    builder.Services.AddScoped<MongoDbSeeder>();
}
else
{
    // Fallback to in-memory repository if MongoDB not configured
    builder.Services.AddSingleton<IBookRepository, InMemoryBookRepository>();
}

// Register external book provider services
// Register each provider separately so they can all be resolved in IEnumerable<IBookProvider>
// Priority order for cover images: ISBNdb > Wikidata > Google Books > Open Library
// builder.Services.AddHttpClient<ISBNdbBookProvider>();
builder.Services.AddHttpClient<WikidataBookProvider>();
builder.Services.AddHttpClient<InventaireBookProvider>();
builder.Services.AddHttpClient<GoogleBooksProvider>();
builder.Services.AddHttpClient<OpenLibraryProvider>();

// Register as IBookProvider implementations in priority order
// builder.Services.AddScoped<IBookProvider, ISBNdbBookProvider>(sp => 
//     sp.GetRequiredService<ISBNdbBookProvider>());
builder.Services.AddScoped<IBookProvider, WikidataBookProvider>(sp => 
    sp.GetRequiredService<WikidataBookProvider>());
builder.Services.AddScoped<IBookProvider, InventaireBookProvider>(sp => 
    sp.GetRequiredService<InventaireBookProvider>());
builder.Services.AddScoped<IBookProvider, GoogleBooksProvider>(sp => 
    sp.GetRequiredService<GoogleBooksProvider>());
builder.Services.AddScoped<IBookProvider, OpenLibraryProvider>(sp => 
    sp.GetRequiredService<OpenLibraryProvider>());

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

// Seed in-memory repository with mock data in development
if (app.Environment.IsDevelopment() && string.IsNullOrEmpty(connectionString))
{
    using (var scope = app.Services.CreateScope())
    {
        var repo = scope.ServiceProvider.GetRequiredService<IBookRepository>();
        await InMemorySeeder.SeedMockBooksAsync(repo);
    }
}

// Seed MongoDB with mock data if configured
if (!string.IsNullOrEmpty(connectionString))
{
    try
    {
        var seedMockData = mongoDbConfig.GetValue<bool>("SeedMockData");
        if (seedMockData)
        {
            using (var scope = app.Services.CreateScope())
            {
                var seeder = scope.ServiceProvider.GetRequiredService<MongoDbSeeder>();
                await seeder.SeedIfEmptyAsync();
            }
        }
    }
    catch (Exception ex)
    {
        var logger = app.Services.GetRequiredService<ILogger<Program>>();
        logger.LogWarning(ex, "Failed to seed MongoDB. Continuing with application startup.");
    }
}

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
