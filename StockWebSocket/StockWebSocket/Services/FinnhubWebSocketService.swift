import Foundation
import Combine

class FinnhubWebSocketService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private let baseURL = URL(string: "wss://ws.finnhub.io")!
    private let apiKey: String
    private var pendingSubscriptions: Set<String> = []
    private var isConnectionReady = false
    private let session: URLSession
    
    // WebSocket message types
    private enum MessageType: String {
        case subscribe = "subscribe"
        case unsubscribe = "unsubscribe"
        case ping = "ping"
        case trade = "trade"
        case error = "error"
    }
    
    @Published var stockData: [String: Double] = [:] // symbol: price
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    
    init(apiKey: String = ApiKey.finnhubApiKey) {
        self.apiKey = apiKey
        
        // Configure URLSession with WebSocket protocols
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: OperationQueue()
        )
    }
    
    func connect() {
        // Close any existing connection
        disconnect()
        
        // Create WebSocket URL with token as query parameter
        let urlString = "\(baseURL.absoluteString)?token=\(apiKey)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Invalid WebSocket URL"
                self?.isConnected = false
            }
            return
        }
        
        print("🔌 Connecting to WebSocket...")
        let request = URLRequest(url: url, timeoutInterval: 10)
        webSocketTask = session.webSocketTask(with: request)
        
        // Set up receive handler before resuming the task
        receiveMessage()
        
        // Set up connection state
        webSocketTask?.resume()
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.isConnectionReady = true
            print("✅ WebSocket connected")
            
            // Process any pending subscriptions after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self = self else { return }
                if !self.pendingSubscriptions.isEmpty {
                    let symbols = Array(self.pendingSubscriptions)
                    self.pendingSubscriptions.removeAll()
                    self.performSubscription(to: symbols)
                }
            }
        }
    }
    
    func subscribe(to symbols: [String]) {
        guard !symbols.isEmpty else { return }
        
        if isConnectionReady {
            performSubscription(to: symbols)
        } else {
            // Queue the subscription for when the connection is ready
            pendingSubscriptions.formUnion(symbols)
            
            // If not connected, try to connect
            if !isConnected {
                connect()
            }
        }
    }
    
    private func performSubscription(to symbols: [String]) {
        guard !symbols.isEmpty else { return }
        
        // For US stocks, we can subscribe directly with the symbol
        // No need for exchange prefix for US stocks in Finnhub
        for symbol in symbols {
            // Create subscription message for the stock symbol
            // Finnhub requires the subscription type to be specified (e.g., "trade" for real-time trades)
            let subscriptionMessage: [String: Any] = [
                "type": MessageType.subscribe.rawValue,
                "symbol": symbol,  // Stock symbol (e.g., "AAPL")
                "subscription": "trade"  // Subscribe to trade data
            ]
            
            do {
                let data = try JSONSerialization.data(withJSONObject: subscriptionMessage, options: [])
                let message = URLSessionWebSocketTask.Message.data(data)
                
                print("🔔 Subscribing to stock: \(symbol)")
                
                webSocketTask?.send(message) { [weak self] error in
                    if let error = error {
                        print("❌ Subscription failed for \(symbol): \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to subscribe to \(symbol)"
                        }
                    } else {
                        print("✅ Subscribed to stock: \(symbol)")
                    }
                }
            } catch {
                print("❌ Error creating subscription message for \(symbol): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error subscribing to \(symbol)"
                }
            }
        }
    }
    
    func unsubscribe(from symbols: [String]) {
        let unsubscribeMessage = [
            "type": "unsubscribe",
            "symbol": symbols.joined(separator: ",")
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: unsubscribeMessage, options: [])
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { _ in }
        } catch {
            errorMessage = "Error creating unsubscribe message: \(error.localizedDescription)"
        }
    }
    
    private func receiveMessage() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                
                // Continue listening for the next message
                if self.isConnected {
                    self.receiveMessage()
                }
                
            case .failure(let error):
                print("❌ WebSocket receive error: \(error.localizedDescription)")
                
                // Only attempt to reconnect if we were connected
                if self.isConnected {
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.isConnectionReady = false
                        self.errorMessage = "Connection lost. Reconnecting..."
                        
                        // Attempt to reconnect after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                            print("🔄 Attempting to reconnect...")
                            self?.connect()
                        }
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                processJSONMessage(json)
            }
            
        case .string(let text):
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                processJSONMessage(json)
            }
            
        @unknown default:
            break
        }
    }
    
    private func processJSONMessage(_ json: [String: Any]) {
        print("\n📩 Received message type: \(json["type"] ?? "unknown")")
        print("📦 Full message: \(json)")
        
        // Check for error message
        if let type = json["type"] as? String, type == MessageType.error.rawValue {
            let errorMsg = json["msg"] as? String ?? "Unknown WebSocket error"
            print("❌ WebSocket error: \(errorMsg)")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = errorMsg
            }
            return
        }
        
        // Check for ping message
        if let type = json["type"] as? String, type == MessageType.ping.rawValue {
            print("🏓 Received ping")
            return
        }
        
        // Check for subscription confirmation
        if let type = json["type"] as? String, type == "welcome" {
            print("🎉 WebSocket connection established successfully")
            return
        }
        
        // Check for subscription success message
        if let type = json["type"] as? String, type == "confirmation" {
            let symbol = json["symbol"] as? String ?? "unknown"
            print("✅ Subscription confirmed for: \(symbol)")
            return
        }
        
        // Process trade data
        if let dataArray = json["data"] as? [[String: Any]] {
            print("📊 Processing \(dataArray.count) data items")
            var updates: [String: Double] = [:] // symbol: price
            
            for item in dataArray {
                // Try different possible field names for symbol and price
                let symbol = (item["s"] as? String) ?? 
                            (item["symbol"] as? String) ?? 
                            (item["ticker"] as? String) ?? ""
                
                let price = (item["p"] as? Double) ?? 
                           (item["price"] as? Double) ??
                           (item["last"] as? Double) ??
                           (item["c"] as? Double) // Some APIs use 'c' for current price
                
                // Extract symbol without exchange prefix if present
                let cleanSymbol = symbol.components(separatedBy: ":").last ?? symbol
                
                if !cleanSymbol.isEmpty, let price = price {
                    print("📊 \(cleanSymbol): $\(price)")
                    updates[cleanSymbol] = price
                } else {
                    print("⚠️ Could not parse price data for item: \(item)")
                }
            }
            
            // Update UI on main thread if we have updates
            if !updates.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    for (symbol, price) in updates {
                        self?.stockData[symbol] = price
                    }
                }
            }
        } else if json["type"] as? String != nil {
            // Log any other message types we're not handling
            print("ℹ️ Received message of type: \(json["type"] ?? "unknown")")
        }
    }
    
    private func setupPingTimer() {
        // Invalidate existing timer if any
        pingTimer?.invalidate()
        
        // Create new timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Send ping every 20 seconds to keep the connection alive
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
                guard let self = self, self.isConnected else { return }
                
                self.webSocketTask?.sendPing { error in
                    if let error = error {
                        print("❌ Ping failed: \(error.localizedDescription)")
                        self.reconnect()
                    } else {
                        print("🏓 Ping sent")
                    }
                }
            }
            
            // Add the timer to the current run loop
            if let timer = self.pingTimer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    private func reconnect() {
        disconnect()
        connect()
    }
    
    func disconnect() {
        print("🛑 Disconnecting WebSocket...")
        
        // Invalidate timer first
        pingTimer?.invalidate()
        pingTimer = nil
        
        // Cancel WebSocket task
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        // Update state on main thread
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.isConnectionReady = false
            // Don't clear pending subscriptions on disconnect as we might want to resubscribe
        }
    }
    
    deinit {
        disconnect()
    }
}
