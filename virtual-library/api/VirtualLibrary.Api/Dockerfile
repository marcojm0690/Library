# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY virtual-library/api/VirtualLibrary.Api/VirtualLibrary.Api.csproj virtual-library/api/VirtualLibrary.Api/
RUN dotnet restore virtual-library/api/VirtualLibrary.Api/VirtualLibrary.Api.csproj

# Copy the rest of the source code
COPY virtual-library/api/VirtualLibrary.Api/ virtual-library/api/VirtualLibrary.Api/

# Publish
RUN dotnet publish virtual-library/api/VirtualLibrary.Api/VirtualLibrary.Api.csproj -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# ASP.NET Core listens on 8080 in containers
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true
ENV ASPNETCORE_ENVIRONMENT=Production

EXPOSE 8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "VirtualLibrary.Api.dll"]
