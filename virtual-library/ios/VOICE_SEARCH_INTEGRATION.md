# Voice Search - Quick Integration Guide

## Adding Voice Search to Your Library View

### Step 1: Import the View

Add to the top of your library detail view file:

```swift
import SwiftUI
```

### Step 2: Add State Variable

In your view struct (e.g., `LibraryDetailView`):

```swift
struct LibraryDetailView: View {
    let library: Library
    @StateObject private var viewModel: LibraryDetailViewModel
    
    // Add this line
    @State private var showVoiceSearch = false
    
    // ... rest of your code
}
```

### Step 3: Add Toolbar Button

Add this to your view's `.toolbar` modifier:

```swift
.toolbar {
    // ... existing toolbar items ...
    
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showVoiceSearch = true }) {
            Label("Voice Search", systemImage: "mic.circle.fill")
        }
    }
}
```

### Step 4: Add Sheet Presentation

Add this modifier to your main view container:

```swift
.sheet(isPresented: $showVoiceSearch) {
    VoiceSearchView(libraryId: library.id) {
        // Refresh library when book is added
        Task {
            await viewModel.loadLibrary()
        }
    }
}
```

## Complete Example

Here's how it looks integrated into a typical library view:

```swift
import SwiftUI

struct LibraryDetailView: View {
    let library: Library
    @StateObject private var viewModel: LibraryDetailViewModel
    @State private var showVoiceSearch = false  // NEW
    
    var body: some View {
        ScrollView {
            VStack {
                // Your existing library content
                ForEach(viewModel.books) { book in
                    BookRowView(book: book)
                }
            }
        }
        .navigationTitle(library.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showVoiceSearch = true }) {  // NEW
                        Label("Voice Search", systemImage: "mic.circle")
                    }
                    
                    // Your other menu items...
                    Button(action: { /* ... */ }) {
                        Label("Scan ISBN", systemImage: "barcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showVoiceSearch) {  // NEW
            VoiceSearchView(libraryId: library.id) {
                Task {
                    await viewModel.loadLibrary()
                }
            }
        }
    }
}
```

## Alternative: Floating Action Button

For a more prominent voice search button:

```swift
ZStack(alignment: .bottomTrailing) {
    // Your main content
    ScrollView {
        // ...
    }
    
    // Floating voice search button
    Button(action: { showVoiceSearch = true }) {
        HStack {
            Image(systemName: "mic.fill")
            Text("Voice Search")
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding()
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
    .padding()
}
```

## Testing

1. Build and run your app
2. Navigate to a library
3. Tap the microphone button (toolbar or FAB)
4. Grant speech recognition permissions when prompted
5. Say a book title (e.g., "The Great Gatsby")
6. See results appear
7. Tap "Add to Library" on a result
8. Verify book appears in your library

## Troubleshooting

**Build Error: "Cannot find 'VoiceSearchView' in scope"**
- Solution: Make sure all files are added to your Xcode project target

**Runtime Error: "Speech recognition not available"**
- Solution: Check Info.plist has both permission keys
- Check user granted permissions in Settings

**No results appearing**
- Solution: Check network connection
- Verify API endpoint is reachable
- Check console logs for API errors

## Next Steps

- Customize button placement and style
- Add analytics tracking
- Implement haptic feedback
- Add voice search tutorial on first use
- Consider adding voice search to onboarding flow
