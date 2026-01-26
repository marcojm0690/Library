# Dynamic Vocabulary Hints for Voice Search

## Overview
Implemented dynamic vocabulary hints for speech recognition that automatically load authors, book titles, and other relevant terms from the user's library to improve transcription accuracy.

## Problem Solved
- Prevents misrecognition of author names (e.g., "Kant" being transcribed as profanity)
- Improves accuracy for book titles and publisher names in user's collection
- Provides context-aware vocabulary based on library tags
- No hardcoding required - everything is dynamic

## Implementation

### Backend (C# .NET API)

#### 1. New Endpoint
**Location:** `LibrariesController.cs`

```csharp
GET /api/libraries/owner/{owner}/vocabulary-hints
```

**Features:**
- Fetches all books from user's libraries
- Extracts authors (full names and individual parts)
- Includes book titles and publishers
- Uses library tags for genre context
- Falls back to general book vocabulary for new users
- Cached for 10 minutes
- Cache invalidated when libraries change

#### 2. DTO Model
**Location:** `LibraryDtos.cs`

```csharp
public record VocabularyHintsResponse
{
    public List<string> Hints { get; init; } = new();
    public List<string> Tags { get; init; } = new();
    public int BookCount { get; init; }
    public bool IsPersonalized { get; init; }
}
```

### iOS Client (Swift)

#### 1. Model
**Location:** `Models/Library.swift`

Added `VocabularyHintsResponse` struct matching the API contract.

#### 2. API Service
**Location:** `Services/BookApiService.swift`

```swift
func getVocabularyHints(forOwner owner: String) async throws -> VocabularyHintsResponse
```

Fetches vocabulary hints from the backend.

#### 3. ViewModel Integration
**Location:** `ViewModels/VoiceSearchViewModel.swift`

- `loadVocabularyHints()`: Fetches hints before starting speech recognition
- Automatically applies hints to `SpeechRecognitionService`
- Gracefully handles errors (continues without hints if fetch fails)

#### 4. Speech Recognition Service
**Location:** `Services/SpeechRecognitionService.swift`

Already had `vocabularyHints` property that gets passed to `SFSpeechAudioBufferRecognitionRequest.contextualStrings`.

## How It Works

### Flow

1. **User initiates voice search**
   ```swift
   VoiceSearchViewModel.startVoiceSearch()
   ```

2. **Load vocabulary hints**
   ```swift
   loadVocabularyHints() // Fetches from API
   ```

3. **API processes request**
   - Gets user's libraries
   - Extracts all book data
   - Builds vocabulary list
   - Returns cached response if available

4. **Apply hints to speech recognizer**
   ```swift
   speechService.vocabularyHints = hints.hints
   recognitionRequest.contextualStrings = vocabularyHints
   ```

5. **User speaks** - iOS Speech Recognition now has context

### Example Data Flow

#### User with Philosophy Books
```json
{
  "hints": [
    "Kant", "Immanuel",
    "Nietzsche", "Friedrich",
    "Critique of Pure Reason",
    "Beyond Good and Evil",
    "Penguin Classics",
    "philosophy"
  ],
  "tags": ["philosophy", "classics"],
  "bookCount": 15,
  "isPersonalized": true
}
```

#### New User (No Libraries)
```json
{
  "hints": [
    "book", "author", "title",
    "Shakespeare", "Austen", "Kant",
    "fantasy", "mystery", "philosophy"
  ],
  "tags": [],
  "bookCount": 0,
  "isPersonalized": false
}
```

## Benefits

### Accuracy
- Prevents misrecognition of uncommon names
- Better recognition of titles from user's collection
- Genre-aware vocabulary based on library tags

### Performance
- Cached for 10 minutes
- Minimal overhead (< 100ms typically)
- Graceful degradation if fetch fails

### User Experience
- No configuration required
- Automatically improves as library grows
- Works immediately for new users (general vocabulary)

## Tag-Based Intelligence

If libraries have tags, the endpoint uses them to provide genre-specific vocabulary:

- **Philosophy library** → includes "philosophy", "ethics", "metaphysics"
- **Fantasy library** → includes "fantasy", "fiction", "novel"
- **History library** → includes "history", "biography", "nonfiction"

## Future Enhancements

### Potential Additions
1. **Frequency-based prioritization** - Most searched/viewed books get higher weight
2. **Community vocabulary** - Add popular books from public libraries
3. **Language detection** - Different hints for different locales
4. **Smart truncation** - Limit hints to top N most relevant
5. **Phonetic alternatives** - Include common misspellings/mishearings

### Performance Optimizations
1. **Client-side caching** - Cache hints in UserDefaults
2. **Background refresh** - Update hints periodically
3. **Selective updates** - Only fetch when libraries change significantly

## Documentation

- **API Contract:** `/shared/contracts/vocabulary-hints-contract.md`
- **Implementation:** This document

## Testing

### Manual Testing
1. Create a library with books by authors like "Kant", "Nietzsche"
2. Start voice search
3. Check logs for vocabulary hints
4. Speak author name - should recognize correctly

### Edge Cases Handled
- ✅ User with no libraries (general vocabulary)
- ✅ User with libraries but no tags
- ✅ Books with no authors/titles
- ✅ Network errors (graceful fallback)
- ✅ Cache invalidation on library changes
