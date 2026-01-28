# Quote Verification & To-Read Library Implementation Guide

## Overview
This document outlines the implementation of two major features:
1. **Quote Verification System** - Verify quotes via text, photo (OCR), or voice
2. **To-Read Library** - Categorize books by reading status

---

## 1. Quote Verification System

### Backend API (✅ Implemented)

**Controller:** `/virtual-library/api/VirtualLibrary.Api/Controllers/QuotesController.cs`

**Endpoint:** `POST /api/quotes/verify`

**Request:**
```json
{
  "quoteText": "I think, therefore I am",
  "claimedAuthor": "Descartes",
  "userId": "user123",
  "inputMethod": "text"  // or "voice" or "photo"
}
```

**Response:**
```json
{
  "originalQuote": "I think, therefore I am",
  "claimedAuthor": "Descartes",
  "isVerified": true,
  "authorVerified": true,
  "overallConfidence": 0.95,
  "inputMethod": "text",
  "possibleSources": [
    {
      "book": {
        "title": "Discourse on Method",
        "authors": ["René Descartes"],
        "publishYear": 1637
      },
      "confidence": 0.95,
      "matchType": "Description Match",
      "source": "Google Books"
    }
  ],
  "context": "This quote appears to be from \"Discourse on Method\" by René Descartes, published in 1637...",
  "recommendedBook": { /* Book object */ }
}
```

### Features:
- **Text Input**: Paste or type quotes directly
- **Photo Input**: OCR from book/screen images
- **Voice Input**: Speech-to-text transcription
- **Verification**: Checks authenticity using Google Books & Open Library APIs
- **Author Verification**: Confirms correct attribution
- **Confidence Scoring**: 0.0 - 1.0 scale based on source matching
- **Context**: Provides background about the quote's origin
- **Book Recommendations**: Suggests adding the source book to library
- **Caching**: 24-hour cache for repeated queries

---

## 2. To-Read Library Feature

### Backend Changes (✅ Implemented)

**Added LibraryType Enum:**
```csharp
public enum LibraryType
{
    Read = 0,
    ToRead = 1,
    Reading = 2,
    Wishlist = 3,
    Favorites = 4
}
```

**Updated Models:**
- `Library.cs` - Added `Type` property
- `LibraryDtos.cs` - Added `Type` to CreateLibraryRequest, UpdateLibraryRequest, LibraryResponse
- `MongoDbLibraryRepository.cs` - Persists `Type` field

**API Changes:**
- `POST /api/libraries` - Now accepts `type` parameter
- `PUT /api/libraries/{id}` - Can update library type
- `GET /api/libraries/*` - Returns library type

---

## 3. iOS Implementation (TODO)

### Quote Verification UI

**Create Files:**

1. **`QuoteVerificationView.swift`** - Main UI
```swift
import SwiftUI

struct QuoteVerificationView: View {
    @StateObject private var viewModel = QuoteVerificationViewModel()
    @State private var inputMethod: InputMethod = .text
    
    enum InputMethod {
        case text, voice, photo
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input method picker
                Picker("Input Method", selection: $inputMethod) {
                    Label("Text", systemImage: "text.quote").tag(InputMethod.text)
                    Label("Voice", systemImage: "mic.fill").tag(InputMethod.voice)
                    Label("Photo", systemImage: "camera.fill").tag(InputMethod.photo)
                }
                .pickerStyle(.segmented)
                
                // Input section based on method
                switch inputMethod {
                case .text:
                    TextEditor(text: $viewModel.quoteText)
                        .frame(height: 150)
                        .border(Color.gray.opacity(0.3))
                    
                case .voice:
                    VoiceInputView(text: $viewModel.quoteText)
                    
                case .photo:
                    PhotoInputView(text: $viewModel.quoteText)
                }
                
                // Author input
                TextField("Claimed Author (optional)", text: $viewModel.claimedAuthor)
                    .textFieldStyle(.roundedBorder)
                
                // Verify button
                Button("Verify Quote") {
                    Task {
                        await viewModel.verifyQuote(inputMethod: inputMethod)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.quoteText.isEmpty)
                
                // Results
                if viewModel.isLoading {
                    ProgressView("Verifying...")
                } else if let result = viewModel.result {
                    QuoteResultView(result: result)
                }
            }
            .padding()
            .navigationTitle("Quote Verification")
        }
    }
}
```

2. **`QuoteVerificationViewModel.swift`**
```swift
import Foundation

@MainActor
class QuoteVerificationViewModel: ObservableObject {
    @Published var quoteText = ""
    @Published var claimedAuthor = ""
    @Published var result: QuoteVerificationResponse?
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService: BookApiService
    
    init(apiService: BookApiService = BookApiService()) {
        self.apiService = apiService
    }
    
    func verifyQuote(inputMethod: QuoteVerificationView.InputMethod) async {
        isLoading = true
        error = nil
        
        do {
            let request = QuoteVerificationRequest(
                quoteText: quoteText,
                claimedAuthor: claimedAuthor.isEmpty ? nil : claimedAuthor,
                userId: UserDefaults.standard.string(forKey: "currentUserId"),
                inputMethod: inputMethod.rawValue
            )
            
            result = try await apiService.verifyQuote(request)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

3. **`QuoteResultView.swift`** - Display verification results
```swift
struct QuoteResultView: View {
    let result: QuoteVerificationResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Verification status
            HStack {
                Image(systemImage: result.isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isVerified ? .green : .red)
                Text(result.isVerified ? "Verified" : "Not Verified")
                    .fontWeight(.bold)
                Spacer()
                Text("\(Int(result.overallConfidence * 100))% confident")
                    .foregroundColor(.secondary)
            }
            
            // Author verification
            if let author = result.claimedAuthor {
                HStack {
                    Image(systemImage: result.authorVerified ? "person.fill.checkmark" : "person.fill.xmark")
                    Text("Author: \(author)")
                    Text(result.authorVerified ? "✓" : "✗")
                        .foregroundColor(result.authorVerified ? .green : .red)
                }
            }
            
            // Context
            if let context = result.context {
                Text(context)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Possible sources
            if !result.possibleSources.isEmpty {
                Text("Possible Sources:")
                    .font(.headline)
                
                ForEach(result.possibleSources, id: \.book.id) { source in
                    SourceBookCard(source: source)
                }
            }
            
            // Add to library button
            if let book = result.recommendedBook {
                Button("Add to To-Read Library") {
                    // TODO: Show library selection
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

4. **Update `BookApiService.swift`** - Add quote verification methods:
```swift
func verifyQuote(_ request: QuoteVerificationRequest) async throws -> QuoteVerificationResponse {
    let url = URL(string: "\(baseURL)/api/quotes/verify")!
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode(QuoteVerificationResponse.self, from: data)
}
```

5. **Models:**
```swift
struct QuoteVerificationRequest: Codable {
    let quoteText: String
    let claimedAuthor: String?
    let userId: String?
    let inputMethod: String
}

struct QuoteVerificationResponse: Codable {
    let originalQuote: String
    let claimedAuthor: String?
    let isVerified: Bool
    let authorVerified: Bool
    let overallConfidence: Double
    let inputMethod: String
    let possibleSources: [QuoteSource]
    let context: String?
    let recommendedBook: Book?
}

struct QuoteSource: Codable {
    let book: Book
    let confidence: Double
    let matchType: String
    let source: String
}
```

### To-Read Library UI

**Update Files:**

1. **`Library.swift`** - Add type property:
```swift
struct LibraryModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let owner: String
    let createdAt: Date
    let updatedAt: Date
    let bookIds: [UUID]
    let bookCount: Int
    let tags: [String]
    let isPublic: Bool
    let type: LibraryType  // ADD THIS
}

enum LibraryType: Int, Codable, CaseIterable {
    case read = 0
    case toRead = 1
    case reading = 2
    case wishlist = 3
    case favorites = 4
    
    var displayName: String {
        switch self {
        case .read: return "Read"
        case .toRead: return "To Read"
        case .reading: return "Currently Reading"
        case .wishlist: return "Wishlist"
        case .favorites: return "Favorites"
        }
    }
    
    var icon: String {
        switch self {
        case .read: return "checkmark.circle.fill"
        case .toRead: return "book.closed"
        case .reading: return "book.circle"
        case .wishlist: return "star"
        case .favorites: return "heart.fill"
        }
    }
}
```

2. **`CreateLibraryView.swift`** - Add type picker:
```swift
Section(header: Text("Library Type")) {
    Picker("Type", selection: $viewModel.type) {
        ForEach(LibraryType.allCases, id: \.self) { type in
            Label(type.displayName, systemImage: type.icon)
                .tag(type)
        }
    }
    .pickerStyle(.menu)
}
```

3. **`LibrariesListView.swift`** - Filter by type:
```swift
// Add filter picker
Picker("Filter", selection: $selectedType) {
    Text("All").tag(LibraryType?.none)
    ForEach(LibraryType.allCases, id: \.self) { type in
        Text(type.displayName).tag(LibraryType?(type))
    }
}
.pickerStyle(.segmented)

// Filter libraries
var filteredLibraries: [LibraryModel] {
    if let type = selectedType {
        return libraries.filter { $0.type == type }
    }
    return libraries
}
```

---

## 4. Features to Implement

### Phase 1: Quote Verification (Text Input)
- [ ] Create QuoteVerificationView
- [ ] Create QuoteVerificationViewModel
- [ ] Add API service methods
- [ ] Create result display UI
- [ ] Add to-read library integration

### Phase 2: Voice Input
- [ ] Reuse existing SpeechRecognitionService
- [ ] Add voice input UI component
- [ ] Integrate with quote verification

### Phase 3: Photo/OCR Input
- [ ] Reuse camera/OCR from book scanning
- [ ] Add photo input UI component
- [ ] Extract quote text from image
- [ ] Integrate with quote verification

### Phase 4: To-Read Library
- [x] Backend: Add LibraryType enum
- [x] Backend: Update DTOs and models
- [x] Backend: Update persistence layer
- [ ] iOS: Update Library model
- [ ] iOS: Add type picker in CreateLibraryView
- [ ] iOS: Add filter in LibrariesListView
- [ ] iOS: Add quick "Add to To-Read" action
- [ ] iOS: Show library type badges/icons

### Phase 5: Enhanced Features
- [ ] Quote sharing (social media)
- [ ] Quote collections/favorites
- [ ] OCR improvements for handwritten quotes
- [ ] ML-based quote completion/suggestion
- [ ] Citation format generation (MLA, APA, Chicago)
- [ ] Integration with Azure OpenAI for context enrichment
- [ ] Batch quote verification
- [ ] Quote of the day feature

---

## 5. API Integration Tips

### Quote Verification Accuracy
- **Google Books API**: Best for published books, provides full-text search
- **Open Library**: Good for older/public domain works
- **Azure OpenAI** (future): Can provide context, verify paraphrases, explain meaning

### Improving Confidence Scores
1. **Exact Match**: 0.95 confidence (quote found in book description)
2. **High Word Match**: 0.7-0.9 (80%+ words match)
3. **Author Match Only**: 0.4 (book by author found, but quote not in description)
4. **No Match**: 0.0

### Cache Strategy
- Cache verified quotes for 24 hours
- Invalidate if book database updates
- Store common/famous quotes permanently

---

## 6. Testing Checklist

### Quote Verification
- [ ] Verify famous quote (Shakespeare)
- [ ] Verify modern quote
- [ ] Test with misattributed quote
- [ ] Test with fake quote
- [ ] Test voice input accuracy
- [ ] Test OCR from clear photo
- [ ] Test OCR from blurry photo
- [ ] Test with non-English quotes

### To-Read Library
- [ ] Create "To Read" library
- [ ] Add book to "To Read" library
- [ ] Move book from "To Read" to "Read"
- [ ] Filter libraries by type
- [ ] Update library type
- [ ] Delete "To Read" library

---

## 7. Future Enhancements

1. **Quote Collections**: Create themed quote collections
2. **Social Features**: Share verified quotes with friends
3. **Reading Progress**: Track books from ToRead → Reading → Read
4. **Goal Setting**: "Read 12 books this year" tracker
5. **Book Recommendations**: Based on to-read list and verified quotes
6. **Quote Discussions**: Community comments on quotes
7. **Author Insights**: Biography and other works when verifying quotes
8. **Citation Generator**: MLA, APA, Chicago formats
9. **Quote Trivia**: "Guess the author" game
10. **Reading Lists**: Public/shared to-read lists

---

## 8. Database Schema Changes

### Library Collection (MongoDB)
```json
{
  "_id": "uuid",
  "name": "My To-Read List",
  "description": "Books I want to read",
  "owner": "user123",
  "createdAt": "2026-01-27T00:00:00Z",
  "updatedAt": "2026-01-27T00:00:00Z",
  "bookIds": ["book-uuid-1", "book-uuid-2"],
  "tags": ["philosophy", "fiction"],
  "isPublic": false,
  "type": 1  // NEW FIELD: 0=Read, 1=ToRead, 2=Reading, 3=Wishlist, 4=Favorites
}
```

No additional collections needed - quotes can be added later if you want to store user's verified quotes.

---

## Summary

✅ **Backend Complete**:
- Quote Verification API endpoint
- LibraryType enum and database support
- Confidence scoring algorithm
- Caching strategy

📱 **iOS TODO**:
- Quote Verification UI (text, voice, photo inputs)
- Result display with source books
- To-Read library type selector
- Library filtering by type
- Quick actions for adding to to-read

🚀 **Deploy**:
```bash
cd infrastructure
./deploy.sh

cd ../scripts
./deploy-webapp.sh
```

The backend is ready to use! Build the iOS UI following the guide above.
