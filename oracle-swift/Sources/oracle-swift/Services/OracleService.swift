//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import SwiftExtensionsPack

public final class OracleWSSService {
    @Atomic static var shared: OracleWSSService = .init()
    private var wsClient: WebSocketClient!
    @Atomic private var pingTimeOut: UInt32 = 20
    @Atomic private var checkPingTimeOut: UInt32 = 5
    var lastPingUnixTime: UInt = Date().toSeconds()
    @Atomic private var queryID: UInt = 0
    @Atomic private var requestsQueue: DispatchQueue = .init(label: "")
    private let lock: NSLock = .init()
    private var requests: [String: ((GQLResponse) async throws -> Void)] = [:]
    private var requestsContinuation: [String: CheckedContinuation<AnyValue, Error>] = [:]
    
    private var connectWatcherStarted: Bool = false
    private var connectWatcherActive: Bool = true
    
    private var pingWatcherStarted: Bool = false
    private var pingWatcherActive: Bool = true
    
    private init() {}
    
    func getQueryId() -> String {
        queryID += 1
        return String(queryID)
    }
    
    func start() async throws {
        wsClient = .init(stringURL: GQL_WSS_ENDPOINT)
        
        wsClient.onConnected { [weak self] ws in
            guard let self = self else { return }
            self.connectWatcherActive = false
            self.pingWatcherActive = true
            logg(text: "WSS Connected")
            try await ws.send(GQLRequest(type: .connection_init).toJson)
            if !pingWatcherStarted {
                try await self.pingWatcher()
            }
        }
        
        wsClient.onText { [weak self] text, ws in
            guard let self = self else { return }
            try await WSSRouter.routing(text: text, self)
        }
        
        wsClient.onDisconnected { error in
            logg(error ?? makeError(OError("Disconnected withou error")))
        }
        
        wsClient.onError { error, ws in
            logg(error)
        }
        
        try await connect()
    }
    
    func send(text: String) async throws {
        try await wsClient.send(text: text)
    }
    
    func send(id: String, request: GQLRequest) async throws -> AnyValue {
        try await withCheckedThrowingContinuation { conn in
            setRequest(id: id, conn: conn)
            Task.detached { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.send(text: request.toJson)
                } catch {
                    self.deleteRequest(id: id)
                    conn.resume(throwing: makeError(OError(String(describing: error))))
                }
            }
        }
    }
    
    func parseResponse(text: String) throws -> GQLResponse {
        pe(text)
        let response: GQLResponse = try text.toModel(GQLResponse.self)
        return response
    }
    
    func handleResponse(response: GQLResponse) async throws {
        let model: GQLResponse = response
        guard let id = model.id else { return }
        let conn: CheckedContinuation<AnyValue, Error> = try getRequest(id: id)
        if model.type == .data {
            guard let payload = model.payload else { throw OError("Payload not found") }
            deleteRequest(id: id)
            if let data = payload.data {
                conn.resume(returning: data)
            } else if let errors = payload.errors, errors.count > 0 {
                conn.resume(throwing: makeError(OError(errors.first!.message)))
            } else {
                conn.resume(throwing: makeError(OError("Unknown response \(payload)")))
            }
        } else if model.type == .error {
            deleteRequest(id: id)
            conn.resume(throwing: makeError(OError("Unknown rules for response type \(model.type.rawValue)")))
        }
    }
    
//    private func terminate() async throws -> String {
//        #"{"type":"connection_error"}"#
//    }
    
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
            if !connectWatcherStarted {
                try await connectWatcher()
            }
            try await wsClient.connect(headers: ["Sec-WebSocket-Protocol": "graphql-ws"])
            lastPingUnixTime = Date().toSeconds()
        }
    }
    
    private func disconnect() async throws {
        try await wsClient.disconnect()
    }
    
    private func reconnect() async throws {
        logg(text: #function)
        pingWatcherActive = false
        connectWatcherActive = true
        try await disconnect()
        try await start()
    }
    
    private func pingWatcher() async throws {
        pingWatcherStarted = true
        Thread { [weak self] in
            while true {
                guard let self = self else { return }
                sleep(Self.shared.checkPingTimeOut)
                let diff: UInt = Date().toSeconds() - self.lastPingUnixTime
                pe(diff, ">", UInt(Self.shared.pingTimeOut))
                if (diff > UInt(Self.shared.pingTimeOut)) && self.pingWatcherActive {
                    Task.detached { [weak self] in
                        try await self?.reconnect()
                    }
                }
            }
        }.start()
    }
    
    private func connectWatcher() async throws {
        connectWatcherStarted = true
        Thread { [weak self] in
            while true {
                if self == nil { return }
                sleep(Self.shared.checkPingTimeOut)
                if self?.connectWatcherActive ?? false {
                    Task.detached { [weak self] in
                        try await self?.reconnect()
                    }
                }
            }
        }.start()
    }
    
    deinit {
        logg(text: "\(Self.self) deinit")
    }
}
