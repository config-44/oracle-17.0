//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import WebSocketKit
import GraphQLWS

/// Messenger wrapper for WebSockets
class WebSocketMessenger: Messenger {
    private weak var websocket: WebSocket?
    private var onReceive: (String) -> Void = { _ in }
    
    init(websocket: WebSocket) {
        self.websocket = websocket
        websocket.onText { _, message in
            self.onReceive(message)
        }
    }
    
    func send<S>(_ message: S) where S: Collection, S.Element == Character {
        guard let websocket = websocket else { return }
        websocket.send(message)
    }
    
    func onReceive(callback: @escaping (String) -> Void) {
        self.onReceive = callback
    }
    
    func error(_ message: String, code: Int) {
        guard let websocket = websocket else { return }
        websocket.send("\(code): \(message)")
    }
    
    func close() {
        guard let websocket = websocket else { return }
        _ = websocket.close()
    }
}
