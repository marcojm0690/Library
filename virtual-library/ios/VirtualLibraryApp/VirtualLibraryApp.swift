import SwiftUI

/// Main entry point for the Virtual Library iOS application.
/// Uses SwiftUI App lifecycle (iOS 14+)
@main
struct VirtualLibraryApp: App {
    @StateObject private var authService = AuthenticationService()
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                HomeView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
