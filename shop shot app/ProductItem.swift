import Foundation

struct ProductItem: Identifiable, Codable {
    var id: UUID
    let image: String
    let searchTerm: String
    
    init(image: String, searchTerm: String) {
        self.id = UUID()
        self.image = image
        self.searchTerm = searchTerm
    }
} 