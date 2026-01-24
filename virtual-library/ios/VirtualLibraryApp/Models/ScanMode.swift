import Foundation

/// Defines the scanning mode for book detection
enum ScanMode {
    case textBased    // CoreML OCR text extraction - extracts and searches by text
    case imageBased   // Image recognition via Azure Vision - searches by cover image
}
