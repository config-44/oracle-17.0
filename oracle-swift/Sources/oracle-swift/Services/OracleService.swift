//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import SwiftExtensionsPack

public final class OracleWSSService {
    static let shared: OracleWSSService = .init()
    private let wsClient: WebSocketClient = .init(stringURL: GQL_WSS_ENDPOINT)
    private var pingTimeOut: UInt32 = 14
    private var checkPingTimeOut: UInt32 = 2
    private var reconnecting: Bool = false
    var lastPingUnixTime: UInt = Date().toSeconds()
    @Atomic private var queryID: UInt = 0
    @Atomic private var requestsQueue: DispatchQueue = .init(label: "")
    private let lock: NSLock = .init()
    private var requests: [String: ((GQLResponse) async throws -> Void)] = [:]
    private var requestsContinuation: [String: CheckedContinuation<AnyValue, Error>] = [:]
    
    private init() {}
    
    func getQueryId() -> String {
        queryID += 1
        return String(queryID)
    }
    
    func start() async throws {
        wsClient.onConnected { [weak self] ws in
            guard let self = self else { return }
            logg("WSS Connected")
            try await ws.send(GQLRequest(type: .connection_init).toJson)
            try await self.pingWatcher()
            
        }
        
        wsClient.onText { text, ws in
            try await WSSRouter.routing(text: text, self)
//            logg(text)
        }
        
        wsClient.onDisconnected { error in
            logg(error ?? OError("Disconnected withou error"))
        }
        
        wsClient.onError { error, ws in
            logg(error)
        }
        
        try await connect()
    }
    
    func send(text: String) async throws {
        try await wsClient.send(text: text)
    }
    
//    func send(request: GQLRequest, _ handler: @escaping ((GQLResponse) async throws -> Void)) async throws {
//        setRequest(id: request.id, handler)
//        try await send(text: request.toJson)
//    }
    
    func send(id: String, request: GQLRequest) async throws -> AnyValue {
        try await withCheckedThrowingContinuation { conn in
            setRequest(id: id, conn: conn)
            Task.detached { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.send(text: request.toJson)
                } catch {
                    conn.resume(throwing: OError(String(describing: error)))
                    self.deleteRequest(id: id)
                }
            }
        }
    }
    
    func parseResponse(text: String) async throws {
        let model: GQLResponse = try text.toModel(GQLResponse.self)
        let conn: CheckedContinuation<AnyValue, Error> = try getRequest(id: model.id)
        if model.type == .data {
            guard let payload = model.payload else { throw OError("Payload not found") }
            if let data = payload.data {
                
                conn.resume(returning: data)
            } else if let errors = payload.errors, errors.count > 0 {
                conn.resume(throwing: OError(errors.first!.message))
            } else {
                conn.resume(throwing: OError("Unknown response \(payload)"))
            }
        } else if model.type == .error {
            conn.resume(throwing: OError("Unknown rules for response type \(model.type.rawValue)"))
        }
    }
    
    private func setRequest(id: String, _ handler: @escaping ((GQLResponse) async throws -> Void)) {
        lock.lock()
        defer { lock.unlock() }
        requests[id] = handler
    }
    
    private func setRequest(id: String, conn: CheckedContinuation<AnyValue, Error>) {
        lock.lock()
        defer { lock.unlock() }
        requestsContinuation[id] = conn
    }
    
    private func getRequest(id: String) throws -> CheckedContinuation<AnyValue, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation = requestsContinuation[id] else { throw OError("requestsContinuation not found") }
        return continuation
    }
    
    private func deleteRequest(id: String) {
        lock.lock()
        defer { lock.unlock() }
        requestsContinuation.removeValue(forKey: id)
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
