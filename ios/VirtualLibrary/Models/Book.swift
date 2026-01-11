import Foundation

struct Book: Identifiable, Codable {
    var id: String { isbn }
    let isbn: String
    let title: String
    let author: String
    let publisher: String
    let publicationYear: Int?
    let description: String
    let coverImageUrl: String
    let categories: [String]
    
    enum CodingKeys: String, CodingKey {
        case isbn
        case title
        case author
        case publisher
        case publicationYear
        case description
        case coverImageUrl
        case categories
    }
}
