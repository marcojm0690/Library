import Foundation

/// Localization keys for the Virtual Library app
enum LocalizedString {
    // MARK: - General
    static let appName = NSLocalizedString("app.name", comment: "Application name")
    static let ok = NSLocalizedString("general.ok", comment: "OK button")
    static let cancel = NSLocalizedString("general.cancel", comment: "Cancel button")
    static let error = NSLocalizedString("general.error", comment: "Error")
    static let loading = NSLocalizedString("general.loading", comment: "Loading")
    static let save = NSLocalizedString("general.save", comment: "Save")
    static let delete = NSLocalizedString("general.delete", comment: "Delete")
    static let edit = NSLocalizedString("general.edit", comment: "Edit")
    static let done = NSLocalizedString("general.done", comment: "Done")
    static let retry = NSLocalizedString("general.retry", comment: "Retry")
    static let close = NSLocalizedString("general.close", comment: "Close")
    
    // MARK: - Home
    static let home = NSLocalizedString("home.title", comment: "Home")
    static let scanISBN = NSLocalizedString("home.scanISBN", comment: "Scan ISBN")
    static let scanCover = NSLocalizedString("home.scanCover", comment: "Scan Cover")
    static let voiceSearch = NSLocalizedString("home.voiceSearch", comment: "Voice Search")
    static let myLibraries = NSLocalizedString("home.myLibraries", comment: "My Libraries")
    static let verifyQuote = NSLocalizedString("home.verifyQuote", comment: "Verify Quote")
    
    // MARK: - Scanner
    static let scannerTitle = NSLocalizedString("scanner.title", comment: "ISBN Scanner")
    static let coverScannerTitle = NSLocalizedString("scanner.coverTitle", comment: "Cover Scanner")
    static let scanInstructions = NSLocalizedString("scanner.instructions", comment: "Point camera at barcode")
    static let takePhoto = NSLocalizedString("scanner.takePhoto", comment: "Take Photo")
    static let chooseFromLibrary = NSLocalizedString("scanner.chooseLibrary", comment: "Choose from Library")
    static let processing = NSLocalizedString("scanner.processing", comment: "Processing image...")
    static let extractingText = NSLocalizedString("scanner.extracting", comment: "Extracting text and searching...")
    
    // MARK: - Books
    static let bookDetails = NSLocalizedString("book.details", comment: "Book Details")
    static let author = NSLocalizedString("book.author", comment: "Author")
    static let publisher = NSLocalizedString("book.publisher", comment: "Publisher")
    static let publishYear = NSLocalizedString("book.publishYear", comment: "Published")
    static let pages = NSLocalizedString("book.pages", comment: "Pages")
    static let isbn = NSLocalizedString("book.isbn", comment: "ISBN")
    static let addToLibrary = NSLocalizedString("book.addToLibrary", comment: "Add to Library")
    static let removeFromLibrary = NSLocalizedString("book.removeFromLibrary", comment: "Remove from Library")
    static let inLibrary = NSLocalizedString("book.inLibrary", comment: "In Library")
    static let searchResults = NSLocalizedString("book.searchResults", comment: "Search Results")
    
    // MARK: - Quote Verification
    static let quoteTitle = NSLocalizedString("quote.title", comment: "Verify Quote")
    static let enterQuote = NSLocalizedString("quote.enter", comment: "Enter quote to verify")
    static let enterAuthor = NSLocalizedString("quote.author", comment: "Author (optional)")
    static let verify = NSLocalizedString("quote.verify", comment: "Verify")
    static let verified = NSLocalizedString("quote.verified", comment: "Quote Verified")
    static let partialVerification = NSLocalizedString("quote.partial", comment: "Partial Verification")
    static let confidenceLevel = NSLocalizedString("quote.confidence", comment: "Confidence Level")
    static let context = NSLocalizedString("quote.context", comment: "Context")
    static let possibleSources = NSLocalizedString("quote.sources", comment: "Possible Sources")
    static let highConfidence = NSLocalizedString("quote.highConfidence", comment: "High confidence - Quote appears authentic")
    static let mediumConfidence = NSLocalizedString("quote.mediumConfidence", comment: "Medium confidence - May require additional verification")
    static let lowConfidence = NSLocalizedString("quote.lowConfidence", comment: "Low confidence - Quote may be inaccurate or false")
    
    // MARK: - Libraries
    static let libraries = NSLocalizedString("library.title", comment: "Libraries")
    static let myLibrary = NSLocalizedString("library.my", comment: "My Library")
    static let createLibrary = NSLocalizedString("library.create", comment: "Create Library")
    static let libraryName = NSLocalizedString("library.name", comment: "Library Name")
    static let booksCount = NSLocalizedString("library.booksCount", comment: "books")
    static let emptyLibrary = NSLocalizedString("library.empty", comment: "No books in this library")
    
    // MARK: - Voice Search
    static let voiceSearchTitle = NSLocalizedString("voice.title", comment: "Voice Search")
    static let tapToSpeak = NSLocalizedString("voice.tapToSpeak", comment: "Tap to speak")
    static let listening = NSLocalizedString("voice.listening", comment: "Listening...")
    static let processing = NSLocalizedString("voice.processing", comment: "Processing...")
    
    // MARK: - Errors
    static let errorGeneric = NSLocalizedString("error.generic", comment: "An error occurred")
    static let errorNetwork = NSLocalizedString("error.network", comment: "Network error. Please check your connection.")
    static let errorBookNotFound = NSLocalizedString("error.bookNotFound", comment: "Book not found")
    static let errorInvalidISBN = NSLocalizedString("error.invalidISBN", comment: "Invalid ISBN")
    static let errorCameraPermission = NSLocalizedString("error.cameraPermission", comment: "Camera permission denied")
    static let errorMicrophonePermission = NSLocalizedString("error.microphonePermission", comment: "Microphone permission denied")
    static let errorPhotoLibraryPermission = NSLocalizedString("error.photoPermission", comment: "Photo library permission denied")
}
