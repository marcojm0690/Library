using VirtualLibrary.Api.Application.Abstractions;
using VirtualLibrary.Api.Application.Books.SearchByIsbn;
using VirtualLibrary.Api.Application.Books.SearchByCover;
using VirtualLibrary.Api.Application.Books.SearchByImage;
using VirtualLibrary.Api.Infrastructure;
using VirtualLibrary.Api.Infrastructure.External;
using VirtualLibrary.Api.Infrastructure.Persistence;
using VirtualLibrary.Api.Infrastructure.Cache;
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;

// Configure MongoDB GUID serialization to use standard representation
BsonSerializer.RegisterSerializer(new GuidSerializer(GuidRepresentation.Standard));

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
    try
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
        
        Console.WriteLine($"MongoDB repositories configured - DB: {databaseName}, Books: {collectionName}, Libraries: {librariesCollectionName}");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"ERROR configuring MongoDB repositories: {ex.Message}");
        throw;
    }
}
else
{
    Console.WriteLine("WARNING: MongoDB connection string not configured. Using in-memory repository.");
    // Fallback to in-memory repository if MongoDB not configured
    builder.Services.AddSingleton<IBookRepository, InMemoryBookRepository>();
    // TODO: Create InMemoryLibraryRepository or throw error
    throw new InvalidOperationException("MongoDB connection string is required for library management");
}

// Register external book provider services
// Register each provider separately so they can all be resolved in IEnumerable<IBookProvider>
// Priority order for cover images: ISBNdb > Wikidata > Google Books > Open Library
// builder.Services.AddHttpClient<ISBNdbBookProvider>();
builder.Services.AddHttpClient<WikidataBookProvider>();
builder.Services.AddHttpClient<InventaireBookProvider>();
builder.Services.AddHttpClient<GoogleBooksProvider>();
builder.Services.AddHttpClient<OpenLibraryProvider>();

// Register Azure Translator service
builder.Services.AddHttpClient<ITranslatorService, AzureTranslatorService>();

// Register as IBookProvider implementations in priority order
// builder.Services.AddScoped<IBookProvider, ISBNdbBookProvider>();
builder.Services.AddScoped<IBookProvider, WikidataBookProvider>();
builder.Services.AddScoped<IBookProvider, InventaireBookProvider>();
builder.Services.AddScoped<IBookProvider, GoogleBooksProvider>();
builder.Services.AddScoped<IBookProvider, OpenLibraryProvider>();

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

// Configure global exception handling
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = 500;
        context.Response.ContentType = "application/json";

        var exceptionHandlerPathFeature = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerPathFeature>();
        var exception = exceptionHandlerPathFeature?.Error;

        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogError(exception, "Unhandled exception occurred: {Path}", context.Request.Path);

        await context.Response.WriteAsJsonAsync(new
        {
            error = "An error occurred processing your request.",
            message = app.Environment.IsDevelopment() ? exception?.Message : "Internal server error",
            path = context.Request.Path.Value
        });
    });
});

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
// Force rebuild Sat Jan 24 20:52:23 CST 2026
