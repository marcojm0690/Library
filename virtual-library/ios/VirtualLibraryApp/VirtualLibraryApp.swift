import SwiftUI

/// Main entry point for the Virtual Library iOS application.
/// Uses SwiftUI App lifecycle (iOS 14+)
@main
struct VirtualLibraryApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
