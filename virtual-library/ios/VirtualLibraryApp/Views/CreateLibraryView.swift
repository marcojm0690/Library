import SwiftUI

/// View for creating a new library
struct CreateLibraryView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel: CreateLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    
    init() {
        // Will be initialized properly in body with environmentObject
        _viewModel = StateObject(wrappedValue: CreateLibraryViewModel(userId: ""))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Library Information")) {
                    TextField("Library Name *", text: $viewModel.name)
                        .autocapitalization(.words)
                    
                    TextEditor(text: $viewModel.description)
                        .frame(height: 100)
                        .overlay(alignment: .topLeading) {
                            if viewModel.description.isEmpty {
                                Text("Description (optional)")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                Section(header: Text("Library Type")) {
                    Picker("Type", selection: $viewModel.libraryType) {
                        ForEach(LibraryType.allCases) { type in
                            Label {
                                Text(type.displayName)
                            } icon: {
                                Image(systemName: type.icon)
                                    .foregroundColor(colorForType(type))
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Add tag", text: $viewModel.currentTag)
                            .autocapitalization(.none)
                            .onSubmit {
                                viewModel.addTag()
                            }
                        
                        Button(action: {
                            viewModel.addTag()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.currentTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    if !viewModel.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.tags, id: \.self) { tag in
                                    TagView(tag: tag) {
                                        viewModel.removeTag(tag)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Public Library", isOn: $viewModel.isPublic)
                } footer: {
                    Text("Public libraries can be viewed by anyone")
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            print("🔵 Create button tapped")
                            print("🔵 User ID: \(authService.user?.id ?? "nil")")
                            print("🔵 Library name: \(viewModel.name)")
                            print("🔵 Is valid: \(viewModel.isValid)")
                            await createLibraryWithUser()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isCreating)
                }
            }
            .onChange(of: viewModel.createdLibrary) { _, library in
                if library != nil {
                    dismiss()
                }
            }
            .overlay {
                if viewModel.isCreating {
                    ProgressView("Creating library...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    private func createLibraryWithUser() async {
        print("🔵 createLibraryWithUser called")
        
        guard let userId = authService.user?.id else {
            print("❌ No user ID found")
            viewModel.error = "User not logged in"
            return
        }
        
        print("✅ User ID: \(userId)")
        
        // Create new view model with user ID
        let vm = CreateLibraryViewModel(userId: userId)
        vm.name = viewModel.name
        vm.description = viewModel.description
        vm.tags = viewModel.tags
        vm.isPublic = viewModel.isPublic
        vm.libraryType = viewModel.libraryType
        
        print("🔵 Calling createLibrary...")
        await vm.createLibrary()
        
        print("🔵 createLibrary finished")
        print("🔵 Created library: \(vm.createdLibrary?.name ?? "nil")")
        print("🔵 Error: \(vm.error ?? "nil")")
        
        if vm.createdLibrary != nil {
            print("✅ Library created successfully, dismissing view")
            dismiss()
        } else if let error = vm.error {
            print("❌ Setting error: \(error)")
            viewModel.error = error
        }
    }
    
    private func colorForType(_ type: LibraryType) -> Color {
        switch type {
        case .read: return .green
        case .toRead: return .blue
        case .reading: return .orange
        case .wishlist: return .purple
        case .favorites: return .red
        }
    }
}

/// Tag view component
struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
}

#Preview {
    CreateLibraryView()
        .environmentObject(AuthenticationService())
}
