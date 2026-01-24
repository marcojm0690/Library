import SwiftUI

struct ModeSelectorSheet: View {
    @Binding var selectedMode: ScanMode
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Modo de Escaneo")
                    .font(.headline)
                    .padding(.top, 20)
                Text("Selecciona cómo detectar libros")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 12) {
                // Image-based mode button
                Button(action: {
                    selectedMode = .imageBased
                    onDismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Reconocimiento de Imagen")
                                    .font(.headline)
                            }
                            Text("Usa Azure Vision para identificar libros por su portada")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if selectedMode == .imageBased {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(selectedMode == .imageBased ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // Text-based mode button
                Button(action: {
                    selectedMode = .textBased
                    onDismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "text.viewfinder")
                                    .font(.title2)
                                Text("Extracción de Texto (CoreML)")
                                    .font(.headline)
                            }
                            Text("Extrae texto con OCR y busca por título/autor")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if selectedMode == .textBased {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(selectedMode == .textBased ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}
