import SwiftUI

struct DetectedBookCard: View {
    let detectedBook: DetectedBook
    let onAdd: () -> Void
    let onDismiss: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwipeComplete = false
    
    // Haptic feedback
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // Background indicators
            HStack {
                // Left side - Add (green)
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                        Text("Agregar")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color.green)
                
                // Right side - Remove (red)
                HStack {
                    VStack {
                        Image(systemName: "trash.fill")
                            .font(.title)
                        Text("Descartar")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.leading, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.red)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(abs(offset) > 10 ? 1 : 0)
            
            // Main card content
            cardContent
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            // Only allow swipe if book is confirmed
                            guard detectedBook.book != nil else { return }
                            offset = gesture.translation.width
                            
                            // Haptic feedback at threshold
                            if abs(gesture.translation.width) > 100 && abs(offset - gesture.translation.width) < 5 {
                                haptic.impactOccurred()
                            }
                        }
                        .onEnded { gesture in
                            guard detectedBook.book != nil else { return }
                            
                            let swipeThreshold: CGFloat = 100
                            
                            if offset < -swipeThreshold {
                                // Swiped left - Add
                                haptic.impactOccurred()
                                withAnimation(.spring()) {
                                    offset = -500
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onAdd()
                                }
                            } else if offset > swipeThreshold {
                                // Swiped right - Remove
                                haptic.impactOccurred()
                                withAnimation(.spring()) {
                                    offset = 500
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } else {
                                // Not enough swipe - reset
                                withAnimation(.spring()) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let book = detectedBook.book {
                // Book details found - compact design
                HStack(spacing: 12) {
                    // Cover image
                    if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .frame(width: 50, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    
                    // Book info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if !book.authors.isEmpty {
                            Text(book.authors.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Swipe hint indicator - only show for confirmed books
                    if detectedBook.book != nil {
                        VStack(spacing: 2) {
                            Image(systemName: "chevron.left.2")
                                .font(.caption2)
                                .foregroundColor(.green.opacity(0.5))
                            Image(systemName: "chevron.right.2")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.5))
                        }
                    }
                }
                .padding(12)
            } else {
                // Only text detected, no book details yet - compact loading state
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 50, height: 75)
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buscando libro...")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(detectedBook.detectedText.prefix(40) + "...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}
