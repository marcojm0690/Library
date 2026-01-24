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
    private let swipeThreshold: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Background swipe indicators with gradient
            HStack(spacing: 0) {
                // Left side - Add (green)
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                            Text("Agregar")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.trailing, 24)
                        .scaleEffect(offset < -swipeThreshold ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: offset < -swipeThreshold)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right side - Dismiss (red)
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    HStack {
                        VStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                            Text("Descartar")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.leading, 24)
                        .scaleEffect(offset > swipeThreshold ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: offset > swipeThreshold)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(abs(offset) > 10 ? min(abs(offset) / 100.0, 1.0) : 0)
            
            // Main card content
            cardContent
                .offset(x: offset)
                .rotationEffect(.degrees(Double(offset) / 20.0))
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            guard detectedBook.book != nil else { return }
                            offset = gesture.translation.width
                            
                            if abs(gesture.translation.width) > swipeThreshold && abs(offset - gesture.translation.width) < 5 {
                                haptic.impactOccurred()
                            }
                        }
                        .onEnded { gesture in
                            guard detectedBook.book != nil else { return }
                            
                            if offset < -swipeThreshold {
                                haptic.impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    offset = -500
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onAdd()
                                }
                            } else if offset > swipeThreshold {
                                haptic.impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    offset = 500
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onDismiss()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .padding(.horizontal, 4)
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let book = detectedBook.book {
                // Book details found - enhanced design
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        // Cover image with better styling
                        if let coverUrl = book.coverImageUrl, let url = URL(string: coverUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            .frame(width: 60, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        } else {
                            // Placeholder when no cover
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Image(systemName: "book.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue.opacity(0.5))
                            }
                            .frame(width: 60, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Book info with better hierarchy
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(isExpanded ? nil : 2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if !book.authors.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text(book.authors.joined(separator: ", "))
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                // Source badge
                                if let source = book.source {
                                    HStack(spacing: 4) {
                                        Image(systemName: source.contains("Vision") ? "eye.fill" : "text.magnifyingglass")
                                            .font(.system(size: 9))
                                        Text(source)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(6)
                                }
                                
                                // Publisher/Year badge
                                if let publisher = book.publisher?.prefix(20), let year = book.publishYear {
                                    HStack(spacing: 4) {
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 9))
                                        Text("\(publisher), \(year)")
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        Spacer(minLength: 8)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                }
                                haptic.impactOccurred()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: isExpanded ? "chevron.up" : "info")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Swipe hint - animated
                            VStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green.opacity(0.6))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                        }
                    }
                    .padding(14)
                    
                    // Expanded details section
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()
                                .padding(.horizontal, 14)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                if let description = book.description, !description.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "text.alignleft")
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue)
                                            Text("Descripción")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Text(description)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                
                                // Metadata grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    if let publisher = book.publisher {
                                        MetadataItem(icon: "building.2", label: "Editorial", value: publisher)
                                    }
                                    
                                    if let year = book.publishYear {
                                        MetadataItem(icon: "calendar", label: "Año", value: "\(year)")
                                    }
                                    
                                    if let pages = book.pageCount {
                                        MetadataItem(icon: "doc.text", label: "Páginas", value: "\(pages)")
                                    }
                                    
                                    if let isbn = book.isbn {
                                        MetadataItem(icon: "barcode", label: "ISBN", value: isbn)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                        ))
                    }
                }
            } else {
                // Loading state with pulse animation
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 90)
                        
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Identificando libro...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text("Analizando portada detectada")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        haptic.impactOccurred()
                        onDismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Helper view for metadata items
struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
