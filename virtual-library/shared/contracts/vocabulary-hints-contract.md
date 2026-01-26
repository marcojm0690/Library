# Vocabulary Hints API Contract

## Get Vocabulary Hints for Speech Recognition

### Endpoint
```
GET /api/libraries/owner/{owner}/vocabulary-hints
```

### Description
Returns vocabulary hints based on the user's library content to improve speech recognition accuracy. Includes authors, book titles, publishers, and tags from the user's libraries. Falls back to general book vocabulary if the user has no libraries.

### Path Parameters
- `owner` (string, required): The user ID/owner identifier

### Response
Status: `200 OK`

```json
{
  "hints": [
    "Kant",
    "Immanuel",
    "Critique of Pure Reason",
    "Shakespeare",
    "William",
    "Hamlet",
    "fantasy",
    "philosophy",
    "Penguin Classics"
  ],
  "tags": [
    "philosophy",
    "fantasy",
    "classics"
  ],
  "bookCount": 42,
  "isPersonalized": true
}
```

### Response Fields
- `hints` (array of strings): List of vocabulary hints including:
  - Full author names
  - Individual name parts (for better recognition)
  - Book titles
  - Publishers
  - Tags
  - Genre terms (if no personalized data available)
- `tags` (array of strings): Tags from user's libraries
- `bookCount` (number): Total number of books in user's libraries
- `isPersonalized` (boolean): 
  - `true` if hints are based on user's actual library content
  - `false` if using general book vocabulary as fallback

### Use Cases

#### Personalized Speech Recognition
When a user has books by authors like "Immanuel Kant", the vocabulary hints will include:
- "Kant"
- "Immanuel"
- "Kant" (as full author name)

This prevents misrecognition of "Kant" as profanity or other similar-sounding words.

#### Tag-Based Context
If a user's libraries have tags like "philosophy" or "science fiction", these are included to help with genre-based searches.

#### Fallback for New Users
Users without libraries receive general book vocabulary including common:
- Search terms (book, author, title, etc.)
- Genres (fantasy, mystery, biography, etc.)
- Classic author names (Shakespeare, Austen, Orwell, etc.)

### Caching
- Response is cached for 10 minutes
- Cache is invalidated when user's libraries are modified (books added/removed, libraries created/deleted)

### Example Usage

```typescript
// Fetch vocabulary hints before starting speech recognition
const response = await fetch('/api/libraries/owner/user123/vocabulary-hints');
const data = await response.json();

// Use hints to configure speech recognizer
speechRecognizer.vocabularyHints = data.hints;
```

### Notes
- Individual name parts are extracted to improve recognition of partial names
- Very short name parts (< 3 characters) are excluded
- Duplicate hints are automatically removed (case-insensitive)
- Hints are sorted alphabetically for consistency
