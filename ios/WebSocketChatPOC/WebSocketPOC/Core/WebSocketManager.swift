import Foundation
import Combine

public class WebSocketManager: NSObject, ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private let url = URL(string: "wss://echo.websocket.events")! // Public WebSocket test server
    
    @Published public private(set) var messages: [String] = []
    @Published public private(set) var isConnected = false
    @Published public var currentMessage = ""
    
    public override init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: configuration)
        super.init()
    }
    
    public func connect() {
        let request = URLRequest(url: url)
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        listenForMessages()
        
        // Send a test message to verify connection
        sendMessage("User has connected")
    }
    
    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("Error receiving message: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self.messages.append(text)
                    }
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    break
                }
                
                // Continue listening for more messages
                self.listenForMessages()
            }
        }
    }
    
    public func sendMessage(_ text: String) {
        guard isConnected else { return }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            }
        }
        
        // Add the sent message to the chat
        DispatchQueue.main.async {
            self.messages.append("You: \(text)")
            self.currentMessage = ""
        }
    }
}