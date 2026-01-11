import SwiftUI

struct BookDetailView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !book.coverImageUrl.isEmpty {
                AsyncImage(url: URL(string: book.coverImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 200)
                .cornerRadius(8)
            }
            
            Text(book.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("by \(book.author)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("ISBN:")
                    .fontWeight(.semibold)
                Text(book.isbn)
            }
            .font(.caption)
            
            if let year = book.publicationYear {
                HStack {
                    Text("Published:")
                        .fontWeight(.semibold)
                    Text("\(year) by \(book.publisher)")
                }
                .font(.caption)
            }
            
            if !book.categories.isEmpty {
                HStack {
                    Text("Categories:")
                        .fontWeight(.semibold)
                    Text(book.categories.joined(separator: ", "))
                }
                .font(.caption)
            }
            
            if !book.description.isEmpty {
                Text("Description")
                    .font(.headline)
                    .padding(.top, 8)
                
                Text(book.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    BookDetailView(book: Book(
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
