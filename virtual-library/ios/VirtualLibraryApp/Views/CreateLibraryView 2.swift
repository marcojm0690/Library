import SwiftUI

/// Sheet to create a new library
struct CreateLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var owner: String = ""
    @State private var descriptionText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiService = BookApiService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detalles de la biblioteca")) {
                    TextField("Nombre", text: $name)
                    TextField("Propietario", text: $owner)
                    TextField("Descripción (opcional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Crear biblioteca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Guardando..." : "Guardar") {
                        Task { await saveLibrary() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func saveLibrary() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let request = CreateLibraryRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText
        )

        do {
            _ = try await apiService.createLibrary(request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateLibraryView()
}
