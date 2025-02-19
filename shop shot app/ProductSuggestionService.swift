import Vision
import UIKit
import CoreML

class ProductSuggestionService {
    static let shared = ProductSuggestionService()
    
    // Common product keywords for better recognition
    private let commonKeywords: [(name: String, keywords: [String])] = [
        ("T-Shirt", ["casual", "cotton", "crew neck", "v-neck"]),
        ("Jeans", ["denim", "pants", "blue jeans", "skinny", "straight leg"]),
        ("Sweater", ["pullover", "knit", "cardigan", "wool"]),
        ("Jacket", ["coat", "outerwear", "bomber", "leather", "denim jacket"]),
        ("Dress", ["gown", "sundress", "formal dress", "casual dress"]),
        ("Sneakers", ["athletic shoes", "trainers", "running shoes", "casual shoes"]),
        ("Watch", ["timepiece", "wristwatch", "smartwatch", "digital watch"]),
        ("Bag", ["handbag", "purse", "tote", "backpack", "shoulder bag"]),
        ("Sunglasses", ["shades", "eyewear", "glasses"])
    ]
    
    func analyzeImageContent(_ image: UIImage, completion: @escaping ([String]) -> Void) {
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
            
            let processedText = recognizedStrings.flatMap { text -> [String] in
                let words = text.components(separatedBy: .whitespacesAndNewlines)
                return words.filter { $0.count > 2 }
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
        
        // Flatten keywords for matching
        let allKeywords = commonKeywords.flatMap { item in
            [item.name] + item.keywords
        }
        
        for result in results {
            if result.count > 2 {
                processedResults.insert(result)
            }
            
            let matchingKeywords = allKeywords.filter { keyword in
                keyword.lowercased().contains(result.lowercased()) ||
                result.lowercased().contains(keyword.lowercased())
            }
            
            processedResults.formUnion(matchingKeywords)
        }
        
        return Array(processedResults)
            .sorted()
            .prefix(5)
            .map { $0.capitalized }
    }
} 