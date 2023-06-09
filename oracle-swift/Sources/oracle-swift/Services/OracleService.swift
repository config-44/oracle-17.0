//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import SwiftExtensionsPack

actor RequestsContinuation {
    var requestsContinuation: [String: CheckedContinuation<AnyValue, Error>] = [:]
    private var queryID: UInt = 0
    
    func nextQueryID() -> String {
        if queryID == UInt.max {
            queryID = 0
        } else {
            queryID += 1
        }
        return String(queryID)
    }
    
    func setRequest(id: String, conn: CheckedContinuation<AnyValue, Error>) {
        if requestsContinuation[id] != nil { fatalError("\(id) already present") }
        requestsContinuation[id] = conn
    }
    
    func getRequest(id: String) -> CheckedContinuation<AnyValue, Error>? {
        requestsContinuation[id]
    }
    
    func deleteRequest(id: String) {
        requestsContinuation.removeValue(forKey: id)
    }
}

public final class OracleWSSService {
    @Atomic static var shared: OracleWSSService = .init()
    private var wsClient: WebSocketClient!
    @Atomic private var pingTimeOut: UInt32 = 20
    @Atomic private var checkPingTimeOut: UInt32 = 5
    var lastPingUnixTime: UInt = Date().toSeconds()
    let requestsActor: RequestsContinuation = .init()
    
    private var connectWatcherStarted: Bool = false
    private var connectWatcherActive: Bool = true
    
    private var pingWatcherStarted: Bool = false
    private var pingWatcherActive: Bool = true
    
    private init() {}
    
    func start() async throws {
        wsClient = .init(stringURL: GQL_WSS_ENDPOINT)
        
        wsClient.onConnected { [weak self] ws in
            guard let self = self else { return }
            self.lastPingUnixTime = Date().toSeconds()
            self.connectWatcherActive = false
            self.pingWatcherActive = true
            let handshakeText: String = GQLRequest(type: .connection_init).toJson
            logg(text: "WSS Connected send handshake \(handshakeText)")
            try await ws.send(handshakeText)
            logg(text: "Handshake has been sent")
            if !pingWatcherStarted {
                try await self.pingWatcher()
            }
        }
        
        wsClient.onText { [weak self] text, ws in
            guard let self = self else { return }
            try await WSSRouter.routing(text: text, self)
        }
        
        wsClient.onDisconnected { error in
            logg(error ?? makeError(OError("Disconnected without error")))
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
        try await withCheckedThrowingContinuation { [id] conn in
            Task.detached { [id, conn, weak self] in
                guard let self = self else {
                    conn.resume(throwing: makeError(OError("Self deinited")))
                    return
                }
                await requestsActor.setRequest(id: id, conn: conn)
                do {
                    try await self.send(text: request.toJson)
                } catch {
                    await requestsActor.deleteRequest(id: id)
                    conn.resume(throwing: makeError(OError(String(describing: error))))
                }
            }
        }
    }
    
    func parseResponse(text: String) throws -> GQLResponse {
        let response: GQLResponse = try text.toModel(GQLResponse.self)
        return response
    }
    
    func handleResponse(response: GQLResponse) async throws {
        guard let id = response.id else { return }
        guard let conn: CheckedContinuation<AnyValue, Error> = await requestsActor.getRequest(id: id) else {
            return
        }
        if response.type == .data {
            guard let payload = response.payload else {
                await requestsActor.deleteRequest(id: id)
                conn.resume(throwing: makeError(OError("Payload not found")))
                return
            }
            await requestsActor.deleteRequest(id: id)
            if let data = payload.data {
                conn.resume(returning: data)
            } else if let errors = payload.errors, errors.count > 0 {
                conn.resume(throwing: makeError(OError(errors.first!.message)))
            } else {
                conn.resume(throwing: makeError(OError("Unknown response \(payload)")))
            }
        } else if response.type == .error {
            await requestsActor.deleteRequest(id: id)
            conn.resume(throwing: makeError(OError("Unknown rules for response type \(response.type.rawValue)")))
        }
    }
    
    private func connect() async throws {
        if wsClient.ws?.isClosed ?? true {
            if !connectWatcherStarted {
                try await connectWatcher()
            }
            try await wsClient.connect(headers: ["Sec-WebSocket-Protocol": "graphql-ws"])
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
//                pe(diff, ">", UInt(Self.shared.pingTimeOut))
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
        Task.detached {
            for conn in await self.requestsActor.requestsContinuation.values {
                conn.resume(throwing: makeError(OError("The class \(Self.self) has been deinitialized")))
            }
        }
    }
}
