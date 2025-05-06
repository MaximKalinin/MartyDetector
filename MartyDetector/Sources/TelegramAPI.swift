import Foundation
import AVFoundation

class TelegramAPI: NSObject {
    private let baseUrl: String
    private let chatId: String
    private let token: String
    
    init(token: String, chatId: String) {
        self.token = token
        self.chatId = chatId
        self.baseUrl = "https://api.telegram.org/bot\(token)"
        super.init()
    }
    
    func sendVideo(videoPath: String, caption: String? = nil) async throws -> [String: Any] {
        print("Sending video")
        let url = URL(string: "\(baseUrl)/sendVideo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let videoSize = try await getVideoSize(videoPath: videoPath)
        
        // Create boundary for multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form data
        var body = Data()
        
        // Add chat_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatId)\r\n".data(using: .utf8)!)
        
        // Add supports_streaming
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"supports_streaming\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        // Add width
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"width\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Int(videoSize.width))\r\n".data(using: .utf8)!)
        
        // Add height
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"height\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Int(videoSize.height))\r\n".data(using: .utf8)!)
        
        // Add caption if provided
        if let caption = caption {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)
        }
        
        // Add video file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(URL(fileURLWithPath: videoPath).lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: URL(fileURLWithPath: videoPath)))
        body.append("\r\n".data(using: .utf8)!)
        
        // Add final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TelegramAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("Telegram API Error Response: \(responseString)")
            }
            throw NSError(domain: "TelegramAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw NSError(domain: "TelegramAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        print("Video sent")
        
        return json
    }
    
    func getVideoSize(videoPath: String) async throws -> CGSize {
        let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        guard let videoTrack = tracks.first else {
            throw NSError(domain: "TelegramAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        return try await videoTrack.load(.naturalSize)
    }
}
