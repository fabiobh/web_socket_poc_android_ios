//
//  MessageBubble.swift
//  WebSocketPOC
//
//  Created by FabioCunha on 12/07/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: String
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            Text(message)
                .padding(12)
                .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(16)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = message.replacingOccurrences(of: "You: ", with: "")
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}
