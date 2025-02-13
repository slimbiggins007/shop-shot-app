import Foundation

struct ProductItem: Identifiable, Codable {
    var id: UUID
    let image: String
    let category: ProductCategory
    let searchTerm: String
    
    init(image: String, category: ProductCategory, searchTerm: String) {
        self.id = UUID()
        self.image = image
        self.category = category
        self.searchTerm = searchTerm
    }
}

enum ProductCategory: String, Codable, CaseIterable {
    case clothing = "Clothing"
    case shoes = "Shoes"
    case books = "Books"
    case other = "Other"
} 