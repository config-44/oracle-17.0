//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import SwiftExtensionsPack

public final class OracleWSSService {
    private let wsClient: WebSocketClient = .init(stringURL: GQL_WSS_ENDPOINT)
    private var pingTimeOut: UInt32 = 14
    private var checkPingTimeOut: UInt32 = 2
    private var reconnecting: Bool = false
    var lastPingUnixTime: UInt = Date().toSeconds()
    static let shared: OracleWSSService = .init()
    
    private init() {}
    
    func start() async throws {
        wsClient.onConnected { [weak self] ws in
            guard let self = self else { return }
            logg("WSS Connected")
            try await ws.send(GQLRequest(type: .connection_init).toJson)
            try await self.pingWatcher()
        }
        
        wsClient.onText { text, ws in
            try await WSSRouter.routing(text: text, self)
        }
        
        wsClient.onDisconnected { error in
            logg(error ?? OError("Disconnected withou error"))
        }
        
        wsClient.onError { error, ws in
            logg(error)
        }
        
        try await connect()
    }
    
    private func connect() async throws {
        if wsClient.ws?.isClosed ?? true {
            try await wsClient.connect(headers: ["Sec-WebSocket-Protocol": "graphql-ws"])
            lastPingUnixTime = Date().toSeconds()
        }
    }
    
    private func disconnect() async throws {
        try await wsClient.disconnect()
    }
    
    private func reconnect() async throws {
        logg(#function)
        reconnecting = true
        try await disconnect()
        try await connect()
        reconnecting = false
    }
    
    private func pingWatcher() async throws {
        Thread { [weak self] in
            while true {
                guard let self = self else { return }
                sleep(self.checkPingTimeOut)
                let diff: UInt = Date().toSeconds() - self.lastPingUnixTime
                if (diff > UInt(self.pingTimeOut)) && !reconnecting {
                    Task.detached { [weak self] in
                        guard let self = self else { return }
                        try await self.reconnect()
                    }
                }
            }
        }.start()
    }
}
