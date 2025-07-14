//
//  HomeView.swift
//  StockWebSocket
//
//  Created by FabioCunha on 12/07/25.
//

import SwiftUI
import Foundation

struct HomeView: View {
    // Market status state
    @State private var marketStatus: (isOpen: Bool, statusMessage: String) = (false, "Checking market status...")
    @State private var timer: Timer?
    
    // WebSocket service and symbols
    @StateObject private var webSocketService = FinnhubWebSocketService()
    @State private var selectedSymbols: Set<String> = ["AAPL", "MSFT", "GOOGL", "AMZN", "META"]
    @State private var lastUpdatedSymbol: String?
    
    var body: some View {
        NavigationView {
            VStack {
                // Market status
                HStack {
                    Circle()
                        .fill(marketStatus.isOpen ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(marketStatus.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Connection status
                HStack {
                    Circle()
                        .fill(webSocketService.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(webSocketService.isConnected ? "WebSocket Connected" : "WebSocket Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let error = webSocketService.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding()
                
                // Stock list
                List {
                    ForEach(Array(webSocketService.stockData.sorted(by: { $0.key < $1.key })), id: \.key) { symbol, price in
                        HStack {
                            Text(symbol)
                                .font(.headline)
                            Spacer()
                            Text(String(format: "$%.2f", price))
                                .font(.body.monospacedDigit())
                                .foregroundColor(price >= 0 ? .green : .red)
                        }
                        .padding(.vertical, 4)
                        .background(
                            Group {
                                if symbol == lastUpdatedSymbol {
                                    Color.yellow.opacity(0.5)
                                        .animation(.easeInOut(duration: 0.3), value: lastUpdatedSymbol)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
                
                // Symbol selector
                VStack(alignment: .leading) {
                    Text("Tracked Stocks")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(["AAPL", "MSFT", "GOOGL", "AMZN", "META", "TSLA", "NFLX", "NVDA"], id: \.self) { symbol in
                                Button(action: {
                                    toggleSymbol(symbol)
                                }) {
                                    Text(symbol)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedSymbols.contains(symbol) ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedSymbols.contains(symbol) ? .white : .primary)
                                        .cornerRadius(15)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Stock Ticker")
            .onAppear {
                webSocketService.connect()
                webSocketService.subscribe(to: Array(selectedSymbols))
                setupMarketStatusCheck()
            }
            .onDisappear {
                webSocketService.disconnect()
                timer?.invalidate()
                timer = nil
            }
            .onReceive(webSocketService.$lastUpdatedSymbol) { symbol in
                lastUpdatedSymbol = symbol
                if symbol != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if lastUpdatedSymbol == symbol {
                            lastUpdatedSymbol = nil
                        }
                    }
                }
            }
        }
    }
    
    private func setupMarketStatusCheck() {
        // Cancel any existing timer
        timer?.invalidate()
        
        // Initial check
        updateMarketStatus()
        
        // Set up new timer
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.updateMarketStatus()
        }
    }
    
    private func updateMarketStatus() {
        // Use the shared instance of MarketHours
        let marketHours = MarketHours.shared
        let newStatus = marketHours.isUSMarketOpen()
        
        // Update the UI on the main thread
        DispatchQueue.main.async {
            self.marketStatus = newStatus
            
            // If market is closed and we're connected, update the status message
            if !newStatus.isOpen && self.webSocketService.isConnected == true {
                self.webSocketService.errorMessage = "Market is closed - data may be delayed"
            }
        }
    }
    
    private func toggleSymbol(_ symbol: String) {
        if selectedSymbols.contains(symbol) {
            selectedSymbols.remove(symbol)
            webSocketService.unsubscribe(from: [symbol])
        } else {
            selectedSymbols.insert(symbol)
            webSocketService.subscribe(to: [symbol])
        }
    }
}

#Preview {
    HomeView()
}
