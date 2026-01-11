import SwiftUI

struct BookRowView: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: book.coverImageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 90)
            .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("ISBN: \(book.isbn)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BookRowView(book: Book(
        isbn: "9780134685991",
        title: "Effective Java",
        author: "Joshua Bloch",
        publisher: "Addison-Wesley",
        publicationYear: 2018,
        description: "A comprehensive guide to best practices in Java programming.",
        coverImageUrl: "https://via.placeholder.com/300x450",
        categories: ["Programming", "Java"]
    ))
    .padding()
}
