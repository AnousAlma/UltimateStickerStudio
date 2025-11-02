import Foundation
import UIKit

enum EditMode {
    case remove
    case add
    case replace
    
    var apiEndpoint: String {
        switch self {
        case .remove:
            return "https://api.stability.ai/v2beta/stable-image/edit/erase"
        case .add:
            return "https://api.stability.ai/v2beta/stable-image/edit/inpaint"
        case .replace:
            return "https://api.stability.ai/v2beta/stable-image/edit/inpaint"
        }
    }
    
    var displayName: String {
        switch self {
        case .remove: return "Remove"
        case .add: return "Add"
        case .replace: return "Replace"
        }
    }
    
    var description: String {
        switch self {
        case .remove: return "Remove objects or backgrounds from the selected area"
        case .add: return "Add new elements to the selected area"
        case .replace: return "Replace the selected area with something new"
        }
    }
    
    var icon: String {
        switch self {
        case .remove: return "minus.circle"
        case .add: return "plus.circle"
        case .replace: return "arrow.triangle.2.circlepath"
        }
    }
}

class ImageProcessor {
    
    private static var apiKey: String {
        return Config.shared.stabilityAIAPIKey
    }
    
    private static func compressImageForAPI(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024
        let maxFileSize = 500_000 // 500KB target
        
        // First resize if needed
        let size = image.size
        var newSize = size
        
        if size.width > maxDimension || size.height > maxDimension {
            let ratio = min(maxDimension / size.width, maxDimension / size.height)
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    static func editImage(
        originalImage: UIImage,
        maskImage: UIImage,
        prompt: String,
        mode: EditMode = .replace
    ) async throws -> UIImage {
        
        guard let url = URL(string: mode.apiEndpoint) else {
            throw ProcessingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        if mode != .remove {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }
        
        // Compress image to stay under API limits
        let compressedImage = compressImageForAPI(originalImage)
        if let imageData = compressedImage.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if mode != .remove {
            let compressedMask = compressImageForAPI(maskImage)
            if let maskData = compressedMask.jpegData(compressionQuality: 0.9) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(maskData)
            body.append("\r\n".data(using: .utf8)!)
            }
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"output_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("png\r\n".data(using: .utf8)!)
        
        switch mode {
        case .remove:
            if !prompt.isEmpty {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"search_prompt\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(prompt)\r\n".data(using: .utf8)!)
            }
        case .add:
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"strength\"\r\n\r\n".data(using: .utf8)!)
            body.append("0.7\r\n".data(using: .utf8)!)
        case .replace:
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"strength\"\r\n\r\n".data(using: .utf8)!)
            body.append("0.9\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid HTTP response")
                throw ProcessingError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Raw API response: \(responseString)")
                
                let decoder = JSONDecoder()
                do {
                    let successResponse = try decoder.decode(ProcessingResponse.self, from: data)
                    
                    guard let imageData = Data(base64Encoded: successResponse.image),
                          let editedImage = UIImage(data: imageData) else {
                        print("Error: Failed to decode image data")
                        throw ProcessingError.invalidImageData
                    }
                    
                    return editedImage.laundered()
                } catch {
                    print("Error: cannot parse response - \(error)")
                    throw ProcessingError.apiError("cannot parse response")
                }
                
            } else {
                print("Error: HTTP \(httpResponse.statusCode)")
                let decoder = JSONDecoder()
                if let errorResponse = try? decoder.decode(ProcessingErrorResponse.self, from: data) {
                    let errorMsg = errorResponse.errors.first ?? "Unknown error"
                    print("Error: \(errorMsg)")
                    throw ProcessingError.apiError(errorMsg)
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("Error: \(errorString)")
                    throw ProcessingError.apiError("HTTP \(httpResponse.statusCode): \(errorString)")
                }
            }
            
        } catch let error as ProcessingError {
            print("Error: \(error.localizedDescription)")
            throw error
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ProcessingError.networkError(error.localizedDescription)
        }
    }
}

struct ProcessingResponse: Codable {
    let image: String
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case image
        case finishReason = "finish_reason"
    }
}

struct ProcessingErrorResponse: Codable {
    let errors: [String]
}

enum ProcessingError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidImageData
    case apiError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidImageData:
            return "Could not process image"
        case .apiError(let message):
            return "Processing Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        }
    }
}

