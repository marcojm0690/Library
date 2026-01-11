# Virtual Library - iOS App

A native iOS application built with SwiftUI using the MVVM architecture for book identification by ISBN barcode scanning or cover image OCR.

## Features

- **Barcode Scanning**: Scan ISBN barcodes using the device camera (AVFoundation)
- **Cover Image OCR**: Take a photo of a book cover and use Vision framework for text recognition
- **API Integration**: Async/await networking to communicate with the backend API
- **Clean Architecture**: MVVM pattern with clear separation of concerns
- **No Storyboards**: Pure SwiftUI implementation

## Architecture

### MVVM Pattern

The app follows the Model-View-ViewModel (MVVM) architectural pattern:

```
ios/VirtualLibrary/
├── Models/              # Data models
│   ├── Book.swift       # Book entity
│   └── APIModels.swift  # Request/Response models
├── ViewModels/          # Business logic and state management
│   └── BookViewModel.swift
├── Views/               # SwiftUI views (no storyboards)
│   ├── ContentView.swift
│   ├── BookDetailView.swift
│   ├── BookRowView.swift
│   ├── BarcodeScannerView.swift
│   └── ImagePickerView.swift
├── Services/            # External integrations
│   ├── BarcodeScannerService.swift  # AVFoundation barcode scanning
│   ├── OCRService.swift             # Vision framework OCR
│   └── APIService.swift             # Async/await API calls
└── VirtualLibraryApp.swift          # App entry point
```

## Services

### BarcodeScannerService
Uses AVFoundation to capture and decode ISBN barcodes (EAN-8, EAN-13, PDF417, QR codes).

**Key Features:**
- Real-time camera preview
- Automatic barcode detection
- Haptic feedback on successful scan

### OCRService
Uses the Vision framework to extract text from book cover images.

**Key Features:**
- Accurate text recognition
- Language correction
- Async/await implementation

### APIService
Handles all API communication using modern async/await patterns.

**Endpoints:**
- `lookupBook(isbn:)` - Look up book by ISBN
- `searchByCover(image:)` - Search books by cover image

## Requirements

- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later
- Device with camera (for barcode scanning and cover image capture)

## Permissions

The app requires the following permissions (defined in `Info.plist`):

- **Camera Access**: For scanning barcodes and taking book cover photos
- **Photo Library Access**: For selecting existing images

## Building and Running

### Using Xcode

1. Open `VirtualLibrary.xcodeproj` in Xcode
2. Select a target device (physical device recommended for camera features)
3. Configure the API base URL in `APIService.swift`:
   ```swift
   init(baseURL: String = "https://your-api-url.com/api")
   ```
4. Build and run (⌘ + R)

### Running on Physical Device

Since the app uses camera features, testing on a physical device is recommended:

1. Connect your iOS device via USB
2. Select your device in Xcode's device selector
3. Trust the developer certificate on your device (Settings → General → Device Management)
4. Run the app

## Usage

### Scanning a Barcode

1. Tap the "Scan Barcode" button
2. Point the camera at an ISBN barcode
3. The app will automatically detect and look up the book

### Scanning a Book Cover

1. Tap the "Scan Cover" button
2. Take a photo of the book cover
3. The app will use OCR to identify the book

### Manual ISBN Entry

1. Tap the "Manual Entry" button
2. Enter the ISBN number
3. Tap "Search" to look up the book

## Configuration

### API Base URL

Update the base URL in `Services/APIService.swift`:

```swift
init(baseURL: String = "https://localhost:5001/api") {
    self.baseURL = baseURL
}
```

For local development with the .NET API:
- Ensure your Mac and the backend server are on the same network
- Use your computer's local IP address (e.g., `http://192.168.1.100:5000/api`)
- Or use `ngrok` to expose the localhost API

## Project Structure

### Models
- **Book**: Core book entity with ISBN, title, author, etc.
- **BookLookupRequest/Response**: API request/response models
- **SearchByCoverRequest/Response**: Cover search API models

### ViewModels
- **BookViewModel**: Manages book data, API calls, and scanner integration
  - Uses Combine for reactive bindings
  - Coordinates between Services and Views
  - Handles loading states and errors

### Views
- **ContentView**: Main app interface with navigation
- **BookDetailView**: Displays detailed book information
- **BookRowView**: List item view for books
- **BarcodeScannerView**: Camera interface for barcode scanning
- **ImagePickerView**: Camera interface for cover photos

### Services
- **BarcodeScannerService**: AVFoundation barcode scanning
- **OCRService**: Vision framework text recognition
- **APIService**: HTTP networking with async/await

## Key Technologies

- **SwiftUI**: Declarative UI framework
- **Combine**: Reactive programming framework
- **AVFoundation**: Camera and barcode scanning
- **Vision**: OCR and image analysis
- **URLSession**: HTTP networking with async/await
- **PhotosUI**: Image picker integration

## Development Notes

- The app uses `@MainActor` for thread-safe UI updates
- All async operations use Swift's modern concurrency (async/await)
- No third-party dependencies - uses only iOS native frameworks
- Follows Swift naming conventions and coding standards

## Future Enhancements

- Offline book storage using Core Data
- Book library management
- Reading list and favorites
- Book sharing and recommendations
- Integration with book reading apps
- Support for iPad and Mac Catalyst
- Dark mode optimization
- Accessibility improvements
- Unit and UI tests
