import Vision
import UIKit
import CoreML

class ProductSuggestionService {
    static let shared = ProductSuggestionService()
    
    // Common product types by category with descriptive terms
    private let suggestions: [ProductCategory: [(name: String, keywords: [String])]] = [
        .clothing: [
            ("T-Shirt", ["casual", "cotton", "crew neck", "v-neck"]),
            ("Jeans", ["denim", "pants", "blue jeans", "skinny", "straight leg"]),
            ("Sweater", ["pullover", "knit", "cardigan", "wool"]),
            ("Jacket", ["coat", "outerwear", "bomber", "leather", "denim jacket"]),
            ("Dress", ["gown", "sundress", "formal dress", "casual dress"]),
            ("Hoodie", ["sweatshirt", "pullover", "zip-up", "hooded"]),
            ("Blazer", ["suit jacket", "formal", "business attire"]),
            ("Skirt", ["midi", "mini", "maxi", "pleated"])
        ],
        .shoes: [
            ("Sneakers", ["athletic shoes", "trainers", "running shoes", "casual shoes"]),
            ("Boots", ["ankle boots", "winter boots", "hiking boots", "combat boots"]),
            ("Sandals", ["flip flops", "slides", "summer shoes", "beach shoes"]),
            ("Heels", ["pumps", "stilettos", "dress shoes", "formal shoes"]),
            ("Athletic Shoes", ["running shoes", "training shoes", "sports footwear"])
        ],
        .books: [
            ("Hardcover", ["book", "novel", "hardback"]),
            ("Paperback", ["book", "soft cover", "pocket book"]),
            ("Textbook", ["educational", "academic", "study material"]),
            ("Magazine", ["periodical", "publication", "glossy"])
        ],
        .other: [
            ("Watch", ["timepiece", "wristwatch", "smartwatch", "digital watch"]),
            ("Bag", ["handbag", "purse", "tote", "backpack", "shoulder bag"]),
            ("Sunglasses", ["shades", "eyewear", "glasses"]),
            ("Jewelry", ["necklace", "bracelet", "ring", "earrings"])
        ]
    ]
    
    func getSuggestions(for category: ProductCategory, matching prefix: String = "") -> [String] {
        let categoryItems = suggestions[category]?.map { $0.name } ?? []
        if prefix.isEmpty {
            return categoryItems
        }
        return categoryItems.filter { $0.lowercased().contains(prefix.lowercased()) }
    }
    
    func analyzeImageContent(_ image: UIImage, completion: @escaping ([String]) -> Void) {
        // Create a dispatch group to handle multiple recognition requests
        let group = DispatchGroup()
        var allResults: Set<String> = []
        
        // 1. Text Recognition
        group.enter()
        recognizeText(in: image) { textResults in
            allResults.formUnion(textResults)
            group.leave()
        }
        
        // 2. Object Recognition
        group.enter()
        recognizeObjects(in: image) { objectResults in
            allResults.formUnion(objectResults)
            group.leave()
        }
        
        // 3. Scene Classification
        group.enter()
        classifyScene(in: image) { sceneResults in
            allResults.formUnion(sceneResults)
            group.leave()
        }
        
        // Process all results
        group.notify(queue: .main) {
            let processedResults = self.processResults(Array(allResults))
            completion(processedResults)
        }
    }
    
    private func recognizeText(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            // Process recognized text to extract brand names and product types
            let processedText = recognizedStrings.flatMap { text -> [String] in
                let words = text.components(separatedBy: .whitespacesAndNewlines)
                return words.filter { $0.count > 2 } // Filter out very short words
            }
            
            completion(processedText)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }
    
    private func recognizeObjects(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNClassifyImageRequest { request, error in
            guard let results = request.results as? [VNClassificationObservation] else {
                completion([])
                return
            }
            
            let topResults = results.prefix(5).compactMap { observation -> String? in
                // Only include results with confidence above 0.3
                guard observation.confidence > 0.3 else { return nil }
                return observation.identifier
                    .split(separator: ",")
                    .first?
                    .trimmingCharacters(in: .whitespaces)
                    .capitalized
            }
            
            completion(topResults)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }
    
    private func classifyScene(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNClassifyImageRequest { request, error in
            guard let results = request.results as? [VNClassificationObservation] else {
                completion([])
                return
            }
            
            let sceneResults = results.prefix(2).compactMap { observation -> String? in
                guard observation.confidence > 0.5 else { return nil }
                return observation.identifier
                    .split(separator: ",")
                    .first?
                    .trimmingCharacters(in: .whitespaces)
                    .capitalized
            }
            
            completion(sceneResults)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }
    
    private func processResults(_ results: [String]) -> [String] {
        var processedResults: Set<String> = []
        
        // Flatten category suggestions for keyword matching
        let allKeywords = suggestions.values.flatMap { categoryItems in
            categoryItems.flatMap { item in
                [item.name] + item.keywords
            }
        }
        
        for result in results {
            // Add the original result if it's long enough
            if result.count > 2 {
                processedResults.insert(result)
            }
            
            // Find matching keywords
            let matchingKeywords = allKeywords.filter { keyword in
                keyword.lowercased().contains(result.lowercased()) ||
                result.lowercased().contains(keyword.lowercased())
            }
            
            processedResults.formUnion(matchingKeywords)
        }
        
        // Sort and limit results
        return Array(processedResults)
            .sorted()
            .prefix(5)
            .map { $0.capitalized }
    }
    
    // Helper function to find the most likely category for a product
    func suggestCategory(from terms: [String]) -> ProductCategory {
        var categoryScores: [ProductCategory: Int] = [:]
        
        for term in terms {
            for (category, items) in suggestions {
                let matches = items.filter { item in
                    item.name.lowercased().contains(term.lowercased()) ||
                    item.keywords.contains { $0.lowercased().contains(term.lowercased()) }
                }
                categoryScores[category, default: 0] += matches.count
            }
        }
        
        return categoryScores.max(by: { $0.value < $1.value })?.key ?? .other
    }
} 