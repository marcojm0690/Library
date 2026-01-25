import SwiftUI

/// Voice-based book search view
/// Allows users to speak a book title/author and get search results
struct VoiceSearchView: View {
    let libraryId: UUID
    let onBookAdded: (() -> Void)?
    
    @StateObject private var viewModel = VoiceSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(libraryId: UUID, onBookAdded: (() -> Void)? = nil) {
        self.libraryId = libraryId
        self.onBookAdded = onBookAdded
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Main content based on state
                    switch viewModel.searchState {
                    case .idle:
                        idleStateView
                        
                    case .listening:
                        listeningStateView
                        
                    case .processing:
                        processingStateView
                        
                    case .results(let books):
                        resultsView(books: books)
                        
                    case .error(let message):
                        errorView(message: message)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        viewModel.cancelVoiceSearch()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isListening {
                        Button("Stop") {
                            viewModel.stopListening()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Say the book title or author")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !viewModel.transcribedText.isEmpty {
                Text("\"\(viewModel.transcribedText)\"")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Idle State
    
    private var idleStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Try saying:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    exampleText("\"The Great Gatsby\"")
                    exampleText("\"1984 by George Orwell\"")
                    exampleText("\"Harry Potter\"")
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Microphone button
            Button(action: { viewModel.startVoiceSearch() }) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    
                    Text("Tap to Start")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 40)
    }
    
    private func exampleText(_ text: String) -> some View {
        HStack {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .italic()
            Spacer()
        }
    }
    
    // MARK: - Listening State
    
    private var listeningStateView: some View {
        VStack(spacing: 30) {
            // Animated waveform
            WaveformAnimationView()
                .frame(height: 100)
            
            Text("Listening...")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Speak clearly into your device")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Stop button
            Button(action: { viewModel.stopListening() }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop Listening")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Processing State
    
    private var processingStateView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Searching for books...")
                .font(.headline)
            
            Text("This should only take a moment")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Results View
    
    private func resultsView(books: [Book]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(books.count) \(books.count == 1 ? "Result" : "Results") Found")
                    .font(.headline)
                Spacer()
                
                Button("Search Again") {
                    viewModel.reset()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(books, id: \.id) { book in
                        BookSearchResultCard(
                            book: book,
                            onAddToLibrary: {
                                Task {
                                    do {
                                        try await viewModel.addBookToLibrary(book, libraryId: libraryId)
                                        onBookAdded?()
                                    } catch {
                                        print("Error adding book: \(error)")
                                    }
                                }
                            },
                            onTap: {
                                // Could navigate to book detail here
                                print("Tapped book: \(book.title)")
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something Went Wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { viewModel.reset() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Waveform Animation View

struct WaveformAnimationView: View {
    @State private var animationPhase = 0.0
    
    let barCount = 5
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8)
                    .frame(height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animationPhase
                    )
            }
        }
        .onReceive(timer) { _ in
            animationPhase += 1
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 20
        let multiplier = sin(animationPhase + Double(index) * 0.5) * 0.5 + 0.5
        return base + (60 * multiplier)
    }
}

// MARK: - Preview

struct VoiceSearchView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceSearchView(libraryId: UUID())
    }
}
