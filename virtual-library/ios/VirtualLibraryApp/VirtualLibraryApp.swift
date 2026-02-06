import SwiftUI

/// Main entry point for the Virtual Library iOS application.
/// Uses SwiftUI App lifecycle (iOS 14+)
@main
struct VirtualLibraryApp: App {
    @StateObject private var authService = AuthenticationService()
    
    init() {
        print("⏱️ [App] VirtualLibraryApp init() at \(Date())")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    HomeView()
                        .environmentObject(authService)
                } else {
                    LoginView()
                        .environmentObject(authService)
                }
            }
            .task {
                print("⏱️ [App] .task modifier running at \(Date())")
                // Initialize auth after UI is ready - non-blocking
                authService.initializeIfNeeded()
            }
            .onAppear {
                print("⏱️ [App] View appeared at \(Date())")
            }
        }
    }
}
