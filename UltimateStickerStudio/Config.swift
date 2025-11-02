import Foundation

class Config {
    static let shared = Config()
    
    private var envVariables: [String: String] = [:]
    
    private init() {
        loadEnvironmentVariables()
    }
    
    private func loadEnvironmentVariables() {
        guard let path = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("ERROR: .env file not found in bundle")
            print("Make sure to add .env file to your Xcode project target")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") {
                    let parts = trimmedLine.components(separatedBy: "=")
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        envVariables[key] = value
                    }
                }
            }
            print("Successfully loaded .env file with \(envVariables.count) variables")
        } catch {
            print("ERROR reading .env file: \(error)")
        }
    }
    
    var stabilityAIAPIKey: String {
        let key = envVariables["STABILITY_AI_API_KEY"] ?? ""
        if key.isEmpty {
            print("ERROR: STABILITY_AI_API_KEY not found in .env file")
        }
        return key
    }
}