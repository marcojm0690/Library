import Foundation

/// ViewModel for library creation
@MainActor
class CreateLibraryViewModel: ObservableObject {
    @Published var name = ""
    @Published var description = ""
    @Published var tags: [String] = []
    @Published var isPublic = false
    @Published var libraryType: LibraryType = .read
    @Published var currentTag = ""
    
    @Published var isCreating = false
    @Published var error: String?
    @Published var createdLibrary: LibraryModel?
    
    private let apiService: BookApiService
    private let userId: String
    
    init(userId: String, apiService: BookApiService = BookApiService()) {
        self.userId = userId
        self.apiService = apiService
    }
    
    /// Validate form inputs
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Add a tag to the list
    func addTag() {
        print("🔵 addTag called with currentTag: '\(currentTag)'")
        let trimmed = currentTag.trimmingCharacters(in: .whitespaces)
        print("🔵 Trimmed tag: '\(trimmed)'")
        
        guard !trimmed.isEmpty else {
            print("❌ Tag is empty after trimming")
            return
        }
        
        guard !tags.contains(trimmed) else {
            print("❌ Tag already exists: '\(trimmed)'")
            return
        }
        
        tags.append(trimmed)
        currentTag = ""
        print("✅ Tag added successfully. Total tags: \(tags.count)")
        print("✅ Tags: \(tags)")
    }
    
    /// Remove a tag from the list
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    /// Create the library
    func createLibrary() async {
        guard isValid else {
            error = "Please fill in all required fields"
            return
        }
        
        isCreating = true
        error = nil
        
        do {
            let request = CreateLibraryRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                owner: userId,
                tags: tags.isEmpty ? nil : tags,
                isPublic: isPublic,
                type: libraryType
            )
            
            createdLibrary = try await apiService.createLibrary(request)
            print("✅ Library created: \(createdLibrary?.name ?? "")")
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to create library: \(error)")
        }
        
        isCreating = false
    }
    
    /// Reset the form
    func reset() {
        name = ""
        description = ""
        tags = []
        libraryType = .read
        isPublic = false
        currentTag = ""
        error = nil
        createdLibrary = nil
    }
}
