# Voice Search Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Voice Search Feature                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            VoiceSearchView (SwiftUI)                     │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  State: Idle                                       │ │  │
│  │  │  - Microphone button                               │ │  │
│  │  │  - Example phrases                                 │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  State: Listening                                  │ │  │
│  │  │  - Animated waveform                               │ │  │
│  │  │  - Real-time transcription                         │ │  │
│  │  │  - Stop button                                     │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  State: Processing                                 │ │  │
│  │  │  - Spinner animation                               │ │  │
│  │  │  - "Searching..." message                          │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  State: Results                                    │ │  │
│  │  │  - ScrollView with BookSearchResultCard list       │ │  │
│  │  │  - Search again button                             │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  State: Error                                      │ │  │
│  │  │  - Error icon                                      │ │  │
│  │  │  - Error message                                   │ │  │
│  │  │  - Try again button                                │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │       BookSearchResultCard (Reusable Component)          │  │
│  │  - Cover image (AsyncImage)                              │  │
│  │  - Title, Authors, ISBN                                  │  │
│  │  - Source badge (GoogleBooks, etc.)                      │  │
│  │  - "Add to Library" button with states:                 │  │
│  │    • Default (blue)                                      │  │
│  │    • Loading (spinner)                                   │  │
│  │    • Success (checkmark)                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ ↑
                          Observes / Updates
                              ↓ ↑
┌─────────────────────────────────────────────────────────────────┐
│                        VIEWMODEL LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         VoiceSearchViewModel (@MainActor)                │  │
│  │                                                          │  │
│  │  @Published Properties:                                  │  │
│  │  - searchState: SearchState                              │  │
│  │  - transcribedText: String                               │  │
│  │  - selectedBook: Book?                                   │  │
│  │                                                          │  │
│  │  Methods:                                                │  │
│  │  - startVoiceSearch()                                    │  │
│  │  - stopListening()                                       │  │
│  │  - cancelVoiceSearch()                                   │  │
│  │  - searchBooks(query:)                                   │  │
│  │  - addBookToLibrary(_:libraryId:)                        │  │
│  │  - reset()                                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                       ↓                    ↓                    │
│              Uses SpeechService    Uses BookApiService          │
└─────────────────────────────────────────────────────────────────┘
                     ↓                      ↓
                     ↓                      ↓
┌─────────────────────────────────────────────────────────────────┐
│                         SERVICE LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────┐  ┌────────────────────────┐ │
│  │  SpeechRecognitionService     │  │  BookApiService        │ │
│  │                               │  │                        │ │
│  │  iOS Frameworks:              │  │  Network Layer:        │ │
│  │  - Speech (SFSpeechRecognizer)│  │  - URLSession          │ │
│  │  - AVFoundation (AudioEngine) │  │  - JSONDecoder         │ │
│  │                               │  │                        │ │
│  │  @Published:                  │  │  Methods:              │ │
│  │  - authorizationStatus        │  │  - searchByCover()     │ │
│  │  - isListening                │  │  - addBookToLibrary()  │ │
│  │  - transcribedText            │  │                        │ │
│  │  - errorMessage               │  │                        │ │
│  │                               │  │                        │ │
│  │  Methods:                     │  │                        │ │
│  │  - requestAuthorization()     │  │                        │ │
│  │  - startListening()           │  │                        │ │
│  │  - stopListening()            │  │                        │ │
│  │  - cancelListening()          │  │                        │ │
│  └───────────────────────────────┘  └────────────────────────┘ │
│            ↓                                    ↓                │
│    iOS Speech Framework              Azure Backend API          │
└─────────────────────────────────────────────────────────────────┘
                     ↓                           ↓
                     ↓                           ↓
┌─────────────────────────────────────────────────────────────────┐
│                      EXTERNAL SYSTEMS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────┐  ┌────────────────────────┐ │
│  │  iOS System Services          │  │  Backend API           │ │
│  │  - Microphone                 │  │                        │ │
│  │  - Speech Recognition         │  │  POST /api/books/      │ │
│  │  - Permissions System         │  │    search-by-cover     │ │
│  │  - Audio Session              │  │                        │ │
│  └───────────────────────────────┘  │  Searches:             │ │
│                                      │  - GoogleBooks         │ │
│                                      │  - OpenLibrary         │ │
│                                      │  - Local DB            │ │
│                                      │                        │ │
│                                      │  Returns:              │ │
│                                      │  - Book metadata       │ │
│                                      │  - Cover images        │ │
│                                      │  - ISBNs               │ │
│                                      └────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
USER ACTION FLOW:

1. User Taps Microphone Button
   │
   ├─> VoiceSearchView renders with state = .idle
   │
   └─> User taps "Start" button
       │
       └─> VoiceSearchViewModel.startVoiceSearch()
           │
           ├─> Check permissions via SpeechRecognitionService
           │   │
           │   ├─> If denied: Show error state
           │   └─> If granted: Continue
           │
           └─> SpeechRecognitionService.startListening()
               │
               ├─> Configure audio session (AVAudioSession)
               ├─> Create recognition request (SFSpeechAudioBufferRecognitionRequest)
               ├─> Install audio tap on input node
               ├─> Start audio engine
               │
               └─> [LISTENING STATE]
                   │
                   ├─> Audio buffers → Recognition request
                   ├─> Real-time results → Update transcribedText
                   └─> View shows animated waveform + transcription
                       │
                       └─> User stops speaking (auto-detected)
                           │
                           └─> Recognition completes with final text
                               │
                               └─> VoiceSearchViewModel.searchBooks(query)
                                   │
                                   └─> [PROCESSING STATE]
                                       │
                                       └─> BookApiService.searchByCover(text)
                                           │
                                           ├─> POST request to backend
                                           │   Body: {"extractedText": "..."}
                                           │
                                           ├─> Backend searches providers
                                           │   - GoogleBooks
                                           │   - OpenLibrary
                                           │   - Local database
                                           │
                                           └─> Returns SearchBooksResponse
                                               │
                                               └─> [RESULTS STATE]
                                                   │
                                                   ├─> Display BookSearchResultCard for each book
                                                   │
                                                   └─> User taps "Add to Library"
                                                       │
                                                       └─> VoiceSearchViewModel.addBookToLibrary()
                                                           │
                                                           └─> BookApiService.addBookToLibrary()
                                                               │
                                                               ├─> POST to backend
                                                               └─> Success!
                                                                   │
                                                                   └─> Card shows checkmark
                                                                   └─> onBookAdded() callback
                                                                   └─> Parent view refreshes
```

## State Machine Diagram

```
VoiceSearchViewModel State Machine:

         ┌─────────────────────────────────────────┐
         │             IDLE                        │
         │  - Show microphone button               │
         │  - Show example phrases                 │
         └─────────────────────────────────────────┘
                         │
                         │ startVoiceSearch()
                         ↓
         ┌─────────────────────────────────────────┐
         │          LISTENING                      │
         │  - Waveform animating                   │
    ┌────┤  - Real-time transcription             ├────┐
    │    │  - Stop button visible                  │    │
    │    └─────────────────────────────────────────┘    │
    │                    │                              │
    │ cancelVoiceSearch()│ stopListening() or           │ error
    │                    │ speech ends                  │
    │                    ↓                              │
    │    ┌─────────────────────────────────────────┐   │
    │    │         PROCESSING                      │   │
    │    │  - Spinner animation                    │   │
    │    │  - "Searching..." text                  │   │
    │    └─────────────────────────────────────────┘   │
    │                    │                              │
    │                    │ search completes             │
    │                    ↓                              │
    │    ┌─────────────────────────────────────────┐   │
    │    │       RESULTS([Book])                   │   │
    │    │  - List of BookSearchResultCards        │   │
    │    │  - "Search Again" button                │   │
    │    └─────────────────────────────────────────┘   │
    │                    │                              │
    │                    │ reset()                      │
    │                    ↓                              ↓
    │    ┌─────────────────────────────────────────────────┐
    └───>│              ERROR(String)                      │
         │  - Error icon                                   │
         │  - Error message                                │
         │  - "Try Again" button                           │
         └─────────────────────────────────────────────────┘
                         │
                         │ reset()
                         ↓
         ┌─────────────────────────────────────────┐
         │             IDLE                        │
         └─────────────────────────────────────────┘
```

## Component Hierarchy

```
VoiceSearchView
│
├─── NavigationView
│    │
│    ├─── Header Section
│    │    ├─── Microphone icon (gradient)
│    │    ├─── Instruction text
│    │    └─── Transcription display (if not empty)
│    │
│    ├─── State-based Content
│    │    │
│    │    ├─── [IDLE]
│    │    │    ├─── Example phrases
│    │    │    └─── Large microphone button
│    │    │
│    │    ├─── [LISTENING]
│    │    │    ├─── WaveformAnimationView
│    │    │    ├─── "Listening..." text
│    │    │    └─── Stop button
│    │    │
│    │    ├─── [PROCESSING]
│    │    │    ├─── ProgressView (spinner)
│    │    │    └─── "Searching..." text
│    │    │
│    │    ├─── [RESULTS]
│    │    │    ├─── Results count header
│    │    │    ├─── "Search Again" button
│    │    │    └─── ScrollView
│    │    │         └─── LazyVStack
│    │    │              └─── ForEach(books)
│    │    │                   └─── BookSearchResultCard
│    │    │                        ├─── Cover image (AsyncImage)
│    │    │                        ├─── Book info (title, authors)
│    │    │                        ├─── Metadata (ISBN, source)
│    │    │                        └─── "Add to Library" button
│    │    │
│    │    └─── [ERROR]
│    │         ├─── Error icon
│    │         ├─── Error message
│    │         └─── "Try Again" button
│    │
│    └─── Toolbar
│         ├─── Close button (leading)
│         └─── Stop button (trailing, if listening)
│
└─── Observed: VoiceSearchViewModel
     │
     ├─── SpeechRecognitionService
     │    └─── iOS Speech Framework
     │
     └─── BookApiService
          └─── Backend API
```

## Sequence Diagram - Happy Path

```
User          View              ViewModel         SpeechService      BookAPI        Backend
 │              │                    │                  │              │               │
 │   Tap Mic    │                    │                  │              │               │
 ├─────────────>│                    │                  │              │               │
 │              │  startVoiceSearch()│                  │              │               │
 │              ├───────────────────>│                  │              │               │
 │              │                    │  startListening()│              │               │
 │              │                    ├─────────────────>│              │               │
 │              │                    │                  │              │               │
 │              │                    │ Permission OK    │              │               │
 │              │                    │<─────────────────┤              │               │
 │              │  state=.listening  │                  │              │               │
 │              │<───────────────────┤                  │              │               │
 │              │                    │                  │              │               │
 │  Speaks      │                    │                  │              │               │
 │ "Gatsby"     │                    │  Real-time text  │              │               │
 │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─>│                  │              │               │
 │              │  Update text       │<─────────────────┤              │               │
 │              │<───────────────────┤                  │              │               │
 │              │                    │                  │              │               │
 │  Stops       │                    │  Final: "The     │              │               │
 │ speaking     │                    │  Great Gatsby"   │              │               │
 │              │                    │<─────────────────┤              │               │
 │              │                    │                  │              │               │
 │              │ state=.processing  │                  │              │               │
 │              │<───────────────────┤                  │              │               │
 │              │                    │  searchByCover("The Great Gatsby")              │
 │              │                    ├─────────────────────────────────>│               │
 │              │                    │                  │   POST        │               │
 │              │                    │                  │   /search     │               │
 │              │                    │                  ├──────────────>│               │
 │              │                    │                  │               │  Query        │
 │              │                    │                  │               │  providers    │
 │              │                    │                  │               ├ ─ ─ ─ ─ ─ ─> │
 │              │                    │                  │               │               │
 │              │                    │                  │               │  Books        │
 │              │                    │                  │               │<─ ─ ─ ─ ─ ─  │
 │              │                    │                  │   200 OK      │               │
 │              │                    │                  │   {books:[]}  │               │
 │              │                    │                  │<──────────────┤               │
 │              │                    │  [Book]          │               │               │
 │              │                    │<─────────────────┤               │               │
 │              │ state=.results([]) │                  │               │               │
 │              │<───────────────────┤                  │               │               │
 │              │                    │                  │               │               │
 │  Sees        │                    │                  │               │               │
 │  results     │                    │                  │               │               │
 │              │                    │                  │               │               │
 │  Tap "Add"   │                    │                  │               │               │
 ├─────────────>│                    │                  │               │               │
 │              │ addBookToLibrary() │                  │               │               │
 │              ├───────────────────>│                  │               │               │
 │              │                    │  addBookToLibrary()              │               │
 │              │                    ├─────────────────────────────────>│               │
 │              │                    │                  │   POST        │               │
 │              │                    │                  │   /library    │               │
 │              │                    │                  ├──────────────>│               │
 │              │                    │                  │               │  Save book    │
 │              │                    │                  │               ├ ─ ─ ─ ─ ─ ─> │
 │              │                    │                  │               │               │
 │              │                    │                  │               │  Success      │
 │              │                    │                  │               │<─ ─ ─ ─ ─ ─  │
 │              │                    │                  │   201 Created │               │
 │              │                    │                  │<──────────────┤               │
 │              │                    │  Success         │               │               │
 │              │                    │<─────────────────┤               │               │
 │              │ Show checkmark     │                  │               │               │
 │              │<───────────────────┤                  │               │               │
 │              │                    │                  │               │               │
 │  Sees ✓      │                    │                  │               │               │
 │<─────────────┤                    │                  │               │               │
 │              │                    │                  │               │               │
```

## Technology Stack Overview

```
┌────────────────────────────────────────────────────┐
│              iOS Application Layer                 │
├────────────────────────────────────────────────────┤
│  SwiftUI (Declarative UI)                          │
│  - Views, Navigation, Animations                   │
├────────────────────────────────────────────────────┤
│  Combine Framework                                 │
│  - @Published properties                           │
│  - ObservableObject protocol                       │
├────────────────────────────────────────────────────┤
│  Swift Concurrency                                 │
│  - async/await                                     │
│  - @MainActor                                      │
│  - Task { }                                        │
├────────────────────────────────────────────────────┤
│  Speech Framework                                  │
│  - SFSpeechRecognizer (on-device ML)               │
│  - SFSpeechAudioBufferRecognitionRequest           │
│  - SFSpeechRecognitionTask                         │
├────────────────────────────────────────────────────┤
│  AVFoundation                                      │
│  - AVAudioEngine (audio capture)                   │
│  - AVAudioSession (audio routing)                  │
├────────────────────────────────────────────────────┤
│  Foundation                                        │
│  - URLSession (networking)                         │
│  - JSONEncoder/Decoder                             │
│  - Date, UUID                                      │
└────────────────────────────────────────────────────┘
```

This architecture provides:
- ✅ Clear separation of concerns
- ✅ Testable components
- ✅ Reusable UI elements
- ✅ Type-safe state management
- ✅ Modern Swift concurrency
- ✅ Responsive UI updates
