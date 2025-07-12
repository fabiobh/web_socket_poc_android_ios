import SwiftUI

struct HomeView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    
    var body: some View {
        VStack {
            // Header with connection status
            HStack {
                Text("WebSocket Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Connection status indicator
                HStack {
                    Circle()
                        .fill(webSocketManager.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(webSocketManager.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                }
            }
            .padding()
            
            // Chat messages
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(webSocketManager.messages.enumerated()), id: \.offset) { _, message in
                            MessageBubble(message: message, isCurrentUser: message.hasPrefix("You: "))
                                .padding(.horizontal)
                                .id(message)
                        }
                    }
                    .padding(.vertical)
                    .onChange(of: webSocketManager.messages) { _ in
                        if let lastMessage = webSocketManager.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $webSocketManager.currentMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                Button(action: {
                    if !webSocketManager.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        webSocketManager.sendMessage(webSocketManager.currentMessage)
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(!webSocketManager.isConnected)
                .opacity(webSocketManager.isConnected ? 1.0 : 0.5)
            }
            .padding()
        }
        .onAppear {
            webSocketManager.connect()
        }
        .onDisappear {
            webSocketManager.disconnect()
        }
    }
}


#Preview {
    HomeView()
}
