import SwiftUI
import AuthenticationServices

/// Login view with Microsoft OAuth
struct LoginView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 40) {
            // App branding
            VStack(spacing: 20) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                Text("Biblioteca Virtual")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Organiza y gestiona tus libros")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // OAuth login buttons
            VStack(spacing: 20) {
                Button(action: loginWithMicrosoft) {
                    HStack {
                        Image(systemName: "microsoft.logo")
                            .font(.title3)
                        Text("Continuar con Microsoft")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Text("Al continuar, aceptas nuestros términos y condiciones")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
        }
        .padding()
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loginWithMicrosoft() {
        // Using existing local sign-in API from AuthenticationService.
        // Replace this with real Microsoft OAuth later if desired.
        isLoading = true
        authService.signIn(fullName: "Usuario", email: nil)
        isLoading = false
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}
