import SwiftUI

/// Main view for verifying quotes via text, voice, or photo
struct QuoteVerificationView: View {
    @StateObject private var viewModel: QuoteVerificationViewModel
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // Voice input
    @State private var showVoiceInput = false
    @State private var isListening = false
    
    // Photo input
    @State private var showPhotoInput = false
    @State private var selectedImage: UIImage?
    
    init(userId: String? = nil) {
        _viewModel = StateObject(wrappedValue: QuoteVerificationViewModel(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: isCompact ? 16 : 24) {
                        // Header
                        headerSection
                        
                        // Input method picker
                        inputMethodPicker
                        
                        // Input section based on selected method
                        inputSection
                        
                        // Verify button
                        verifyButton
                        
                        // Results or loading
                        if viewModel.isLoading {
                            loadingView
                        } else if let result = viewModel.result {
                            QuoteResultView(result: result, onAddToLibrary: { book in
                                // TODO: Show library selection
                            })
                            .transition(.opacity.combined(with: .scale))
                        } else if let error = viewModel.error {
                            errorView(error)
                        }
                    }
                    .padding(isCompact ? 16 : 24)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Verificar Cita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.reset) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.quoteText.isEmpty && viewModel.claimedAuthor.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Computed Properties
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: isCompact ? 50 : 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Verifica la autenticidad de una cita")
                .font(isCompact ? .subheadline : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, isCompact ? 8 : 16)
    }
    
    // MARK: - Input Method Picker
    
    private var inputMethodPicker: some View {
        Picker("Método de entrada", selection: $viewModel.selectedInputMethod) {
            Label("Texto", systemImage: "text.quote")
                .tag(QuoteInputMethod.text)
            Label("Voz", systemImage: "mic.fill")
                .tag(QuoteInputMethod.voice)
            Label("Foto", systemImage: "camera.fill")
                .tag(QuoteInputMethod.photo)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, isCompact ? 0 : 20)
    }
    
    // MARK: - Input Section
    
    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 16) {
            switch viewModel.selectedInputMethod {
            case .text:
                textInputSection
            case .voice:
                voiceInputSection
            case .photo:
                photoInputSection
            }
            
            // Author field (common for all methods)
            authorInputField
        }
        .padding(isCompact ? 16 : 20)
        .background(Color(.systemBackground))
        .cornerRadius(isCompact ? 12 : 16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cita")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextEditor(text: $viewModel.quoteText)
                .frame(minHeight: isCompact ? 120 : 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.quoteText.isEmpty {
                        Text("Escribe o pega la cita aquí...")
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    private var voiceInputSection: some View {
        VStack(spacing: 16) {
            if viewModel.quoteText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: isListening ? "waveform" : "mic.circle.fill")
                        .font(.system(size: isCompact ? 50 : 60))
                        .foregroundColor(isListening ? .red : .blue)
                        .symbolEffect(.variableColor, isActive: isListening)
                    
                    Text(isListening ? "Escuchando..." : "Toca para hablar")
                        .font(isCompact ? .subheadline : .body)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showVoiceInput = true
                    }) {
                        Label(isListening ? "Detener" : "Iniciar grabación", systemImage: isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isListening ? Color.red : Color.blue)
                            .cornerRadius(12)
                    }
                }
                .frame(minHeight: isCompact ? 120 : 150)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cita detectada")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.quoteText = ""
                        }) {
                            Label("Borrar", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                    
                    Text(viewModel.quoteText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var photoInputSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Imagen seleccionada")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            selectedImage = nil
                            viewModel.quoteText = ""
                        }) {
                            Label("Cambiar", systemImage: "photo")
                                .font(.caption)
                        }
                    }
                    
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: isCompact ? 150 : 200)
                        .cornerRadius(8)
                    
                    if !viewModel.quoteText.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Texto extraído:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.quoteText)
                                .font(.subheadline)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: isCompact ? 50 : 60))
                        .foregroundColor(.blue)
                    
                    Text("Selecciona una foto con la cita")
                        .font(isCompact ? .subheadline : .body)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showPhotoInput = true
                    }) {
                        Label("Seleccionar foto", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .frame(minHeight: isCompact ? 120 : 150)
            }
        }
    }
    
    private var authorInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Autor (opcional)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextField("Nombre del autor", text: $viewModel.claimedAuthor)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.words)
        }
    }
    
    // MARK: - Verify Button
    
    private var verifyButton: some View {
        Button(action: {
            Task {
                await viewModel.verifyQuote()
            }
        }) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                Text("Verificar Cita")
                    .fontWeight(.semibold)
            }
            .font(isCompact ? .body : .headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(isCompact ? 14 : 16)
            .background(
                LinearGradient(
                    colors: viewModel.quoteText.isEmpty ? [.gray] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(isCompact ? 12 : 14)
            .shadow(color: Color.blue.opacity(viewModel.quoteText.isEmpty ? 0 : 0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.quoteText.isEmpty || viewModel.isLoading)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Verificando cita...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Buscando en múltiples fuentes...")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(isCompact ? 32 : 40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(isCompact ? 12 : 16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    QuoteVerificationView()
        .environmentObject(AuthenticationService())
}
