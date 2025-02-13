import Vision
import UIKit

class ProductAIService {
    static let shared = ProductAIService()
    
    func analyzeImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }
        
        // Create a dispatch group to handle multiple recognition requests
        let group = DispatchGroup()
        var detectedTerms: Set<String> = []
        
        // 1. Text Recognition
        group.enter()
        recognizeText(in: ciImage) { terms in
            detectedTerms.formUnion(terms)
            group.leave()
        }
        
        // 2. Object Recognition
        group.enter()
        recognizeObjects(in: ciImage) { terms in
            detectedTerms.formUnion(terms)
            group.leave()
        }
        
        // Process results
        group.notify(queue: .main) {
            let searchTerm = self.processTerms(Array(detectedTerms))
            completion(searchTerm.isEmpty ? nil : searchTerm)
        }
    }
    
    private func recognizeText(in image: CIImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let words = recognizedStrings.flatMap { text -> [String] in
                text.components(separatedBy: .whitespacesAndNewlines)
                    .filter { $0.count > 2 }
            }
            
            completion(words)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(ciImage: image)
        try? handler.perform([request])
    }
    
    private func recognizeObjects(in image: CIImage, completion: @escaping ([String]) -> Void) {
        let request = VNClassifyImageRequest { request, error in
            guard let observations = request.results as? [VNClassificationObservation] else {
                completion([])
                return
            }
            
            let terms = observations.prefix(3).compactMap { observation -> String? in
                guard observation.confidence > 0.3 else { return nil }
                return observation.identifier
                    .split(separator: ",")
                    .first?
                    .trimmingCharacters(in: .whitespaces)
            }
            
            completion(terms.map { $0.capitalized })
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        try? handler.perform([request])
    }
    
    private func processTerms(_ terms: [String]) -> String {
        // Filter and clean up terms
        let processedTerms = terms
            .filter { $0.count > 2 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Join terms with spaces, limiting to first few meaningful terms
        return processedTerms
            .prefix(3)
            .joined(separator: " ")
    }
    
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        
        // Apply filters to improve text recognition
        let filters: [(CIFilter?, String)] = [
            (CIFilter(name: "CIColorControls", parameters: [
                kCIInputContrastKey: 1.1,
                kCIInputBrightnessKey: 0.1
            ]), "Contrast"),
            (CIFilter(name: "CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.5,
                kCIInputIntensityKey: 0.5
            ]), "Sharpness"),
            (CIFilter(name: "CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.7, green: 0.7, blue: 0.7),
                kCIInputIntensityKey: 0.8
            ]), "Monochrome")
        ]
        
        var processedImage = ciImage
        
        for (filter, _) in filters {
            filter?.setValue(processedImage, forKey: kCIInputImageKey)
            if let outputImage = filter?.outputImage {
                processedImage = outputImage
            }
        }
        
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // Backup method using object detection
    func detectObjects(_ image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let _ = results.first else {
                completion(nil)
                return
            }
            
            // If we detect a rectangle (likely a product), generate a generic shopping URL
            let searchURL = URL(string: "https://www.amazon.com/s?k=product")
            completion(searchURL)
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage)
        try? handler.perform([request])
    }
} 