import Foundation
import SwiftUI

class ProductDataManager: ObservableObject {
    @Published var products: [ProductItem] = []
    private let saveKey = "SavedProducts"
    
    init() {
        loadProducts()
    }
    
    func addProduct(image: UIImage, searchTerm: String) {
        if let imageName = saveImage(image) {
            let newProduct = ProductItem(
                image: imageName,
                searchTerm: searchTerm
            )
            products.append(newProduct)
            saveProducts()
        }
    }
    
    func updateProduct(_ product: ProductItem, newSearchTerm: String) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = ProductItem(
                image: product.image,
                searchTerm: newSearchTerm
            )
            saveProducts()
        }
    }
    
    private func saveImage(_ image: UIImage) -> String? {
        let imageName = UUID().uuidString + ".jpg"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageUrl = documentsDirectory.appendingPathComponent(imageName)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: imageUrl)
            return imageName
        }
        return nil
    }
    
    func loadImage(_ imageName: String) -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageUrl = documentsDirectory.appendingPathComponent(imageName)
        return UIImage(contentsOfFile: imageUrl.path)
    }
    
    private func saveProducts() {
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadProducts() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ProductItem].self, from: data) {
            products = decoded
        }
    }
    
    func deleteProduct(_ product: ProductItem) {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imageUrl = documentsDirectory.appendingPathComponent(product.image)
            try? FileManager.default.removeItem(at: imageUrl)
        }
        
        products.removeAll { $0.id == product.id }
        saveProducts()
    }
} 