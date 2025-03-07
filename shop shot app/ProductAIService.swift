import Vision
import UIKit

class ProductAIService {
    static let shared = ProductAIService()
    
    func analyzeImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let preprocessedImage = preprocessImage(image),
              let cgImage = preprocessedImage.cgImage else {
            completion(nil)
            return
        }
        
        let group = DispatchGroup()
        var detectedTerms: Set<String> = []
        
        // 1. Enhanced Text Recognition
        group.enter()
        recognizeText(in: cgImage) { terms in
            detectedTerms.formUnion(terms)
            group.leave()
        }
        
        // 2. Object Recognition with confidence threshold
        group.enter()
        recognizeObjects(in: cgImage) { terms in
            detectedTerms.formUnion(terms)
            group.leave()
        }
        
        // Process results
        group.notify(queue: .main) {
            let searchTerm = self.processTerms(Array(detectedTerms))
            completion(searchTerm.isEmpty ? nil : searchTerm)
        }
    }
    
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext()
        
        // Enhanced preprocessing pipeline
        let filters: [(CIFilter?, String)] = [
            (CIFilter(name: "CIColorControls", parameters: [
                kCIInputContrastKey: 1.2,
                kCIInputBrightnessKey: 0.1,
                kCIInputSaturationKey: 1.1
            ]), "Enhance"),
            (CIFilter(name: "CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 2.0,
                kCIInputIntensityKey: 0.8
            ]), "Sharpen"),
            (CIFilter(name: "CIExposureAdjust", parameters: [
                kCIInputEVKey: 0.5
            ]), "Exposure")
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
    
    private func recognizeText(in cgImage: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            let recognizedStrings = observations.compactMap { observation -> String? in
                // Get multiple candidates and filter by confidence
                let candidates = observation.topCandidates(3)
                return candidates.first { candidate in
                    candidate.confidence > 0.6
                }?.string
            }
            
            // Enhanced text processing
            let words = recognizedStrings.flatMap { text -> [String] in
                text.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                    .filter { $0.count > 2 }
                    .filter { !$0.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }) }
            }
            
            completion(words)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func recognizeObjects(in cgImage: CGImage, completion: @escaping ([String]) -> Void) {
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
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
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
