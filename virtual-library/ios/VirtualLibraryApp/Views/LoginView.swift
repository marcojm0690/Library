import SwiftUI

/// Login view with simple local authentication (no Sign in with Apple required)
struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var fullName = ""
    @State private var email = ""
    @State private var showError = false

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
            
            // Simple login form
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tu Nombre")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Nombre completo", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email (opcional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("tu@email.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                Button(action: {
                    guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
                        showError = true
                        return
                    }
                    authService.signIn(
                        fullName: fullName,
                        email: email.isEmpty ? nil : email
                    )
                }) {
                    Text("Comenzar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(fullName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                
                if showError {
                    Text("Por favor ingresa tu nombre")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}
