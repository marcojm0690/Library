import SwiftUI

struct DetectedBookCard: View {
    let detectedBook: DetectedBook
    let onAdd: () -> Void
    let onDismiss: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwipeComplete = false
    @State private var isExpanded = false
    
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
                VStack(alignment: .leading, spacing: 0) {
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
                                .lineLimit(isExpanded ? nil : 2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if !book.authors.isEmpty {
                                Text(book.authors.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            // Show source badge
                            if let source = book.source {
                                HStack(spacing: 4) {
                                    Image(systemName: source.contains("Vision") ? "eye.fill" : "text.magnifyingglass")
                                        .font(.system(size: 8))
                                    Text(source)
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                        
                        Spacer()
                        
                        // Expand/collapse button and swipe hint
                        VStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "info.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            
                            // Swipe hint indicator
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
                    
                    // Expanded details section
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            
                            if let description = book.description, !description.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Descripción")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Text(description)
                                        .font(.caption)
                                        .lineLimit(4)
                                }
                            }
                            
                            HStack(spacing: 16) {
                                if let publisher = book.publisher {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Editorial")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(publisher)
                                            .font(.caption)
                                    }
                                }
                                
                                if let year = book.publishYear {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Año")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(year)")
                                            .font(.caption)
                                    }
                                }
                                
                                if let pages = book.pageCount {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Páginas")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(pages)")
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            if let isbn = book.isbn {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ISBN")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(isbn)
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }
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
