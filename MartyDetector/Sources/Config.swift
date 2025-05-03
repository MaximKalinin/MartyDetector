import Foundation

enum ConfigError: Error {
    case missingEnvironmentVariable(String)
}

class Config {
    static let shared = Config()
    
    private init() {}
    
    func loadFromEnv() throws -> (token: String, chatId: String) {
        // First try to load from environment variables
        if let token = ProcessInfo.processInfo.environment["TELEGRAM_BOT_TOKEN"],
           let chatId = ProcessInfo.processInfo.environment["TELEGRAM_CHAT_ID"] {
            return (token: token, chatId: chatId)
        }
        
        // If not found in environment, try to load from .env file
        guard let envURL = Bundle.main.url(forResource: "", withExtension: "env") else {
            throw ConfigError.missingEnvironmentVariable("Could not create url for .env file")
        }
        guard let envContents = try? String(contentsOf: envURL, encoding: .utf8) else {
            throw ConfigError.missingEnvironmentVariable("Could not find .env file")
        }
        
        var token: String?
        var chatId: String?
        
        let lines = envContents.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "TELEGRAM_BOT_TOKEN":
                token = value
            case "TELEGRAM_CHAT_ID":
                chatId = value
            default:
                break
            }
        }
        
        guard let token = token, let chatId = chatId else {
            throw ConfigError.missingEnvironmentVariable("Missing required environment variables")
        }
        
        return (token: token, chatId: chatId)
    }
    
    func listAllEnvironmentVariables() {
        let environment = ProcessInfo.processInfo.environment
        print("Available environment variables:")
        for (key, value) in environment.sorted(by: { $0.key < $1.key }) {
            print("\(key) = \(value)")
        }
    }
} 
