//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import WebSocketKit
import NIOSSL

final class WebSocketClient {
    
    var url: URL
    private var eventLoopGroup: EventLoopGroup
    private let lock: NSLock = .init()
    private weak var _ws: WebSocket?
    weak var ws: WebSocket? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _ws
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _ws = newValue
        }
    }
    
    init(stringURL: String, coreCount: Int = System.coreCount) {
        url = URL(string: stringURL)!
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: coreCount)
    }
    
    /// ASYNC
    private var _onConnectedAsync: ((_ ws: WebSocket) async throws -> Void)?
    private var _onDisconnectedAsync: ((_ error: Error?) async throws -> Void)?
    private var _onCancelledAsync: (() async throws -> Void)?
    private var _onTextAsync: ((_ text: String, _ ws: WebSocket) async throws -> Void)?
    private var _onBinaryAsync: ((_ data: Data, _ ws: WebSocket) async throws -> Void)?
    private var _onPingAsync: ((_ ws: WebSocket) async throws -> Void)?
    private var _onPongAsync: ((_ ws: WebSocket) async throws -> Void)?
    private var _onErrorAsync: ((_ error: Error, _ ws: WebSocket?) async throws -> Void)?
    @Atomic private var connected: Bool = false
    
    /// ASYNC
    func onConnected(_ handler: @escaping ((_ ws: WebSocket) async throws -> Void)) {
        _onConnectedAsync = handler
    }
    
    func onDisconnected(_ handler: @escaping ((_ error: Error?) async throws -> Void)) {
        _onDisconnectedAsync = handler
    }
    
    func onCancelled(_ handler: @escaping (() async throws -> Void)) {
        _onCancelledAsync = handler
    }
    
    func onText(_ handler: @escaping ((_ text: String, _ ws: WebSocket) async throws -> Void)) {
        _onTextAsync = handler
    }
    
    func onBinary(_ handler: @escaping ((_ data: Data, _ ws: WebSocket) async throws -> Void)) {
        _onBinaryAsync = handler
    }
    
    func onPing(_ handler: @escaping ((_ ws: WebSocket) async throws -> Void)) {
        _onPingAsync = handler
    }
    
    func onPong(_ handler: @escaping ((_ ws: WebSocket) async throws -> Void)) {
        _onPongAsync = handler
    }
    
    func onError(_ handler: @escaping ((_ error: Error, _ ws: WebSocket?) async throws -> Void)) {
        _onErrorAsync = handler
    }
    
    func connect(headers: [String: String]? = nil,
                 configuration: WebSocketKit.WebSocketClient.Configuration = .init(tlsConfiguration: TLSConfiguration.clientDefault)
    ) async throws {
        var httpHeaders: HTTPHeaders = .init()
        headers?.forEach({ (name, value) in
            httpHeaders.add(name: name, value: value)
        })
        try await WebSocket.connect(to: url.absoluteString,
                          headers: httpHeaders,
                          configuration: configuration,
                          on: eventLoopGroup
        ) { [weak self] ws in
            do {
                if !(self?.connected ?? true) {
                    self?.ws = ws
                    self?.connected = true
                    try await self?._onConnectedAsync?(ws)
                }
                
                ws.onPing { [weak self] (ws, data) in
                    guard let self = self else { return }
                    do {
                        try await self._onPingAsync?(ws)
                    } catch {
                        try? await self._onErrorAsync?(error, ws)
                    }
                }
                
                ws.onPong { [weak self] (ws, data) in
                    do {
                        try await self?._onPongAsync?(ws)
                    } catch {
                        try? await self?._onErrorAsync?(error, ws)
                    }
                }
                
                ws.onClose.whenComplete { [weak self] (result) in
                    self?.connected = false
                    Task.detached { [weak self] in
                        do {
                            switch result {
                            case .success:
                                try await self?._onDisconnectedAsync?(nil)
                                try await self?._onCancelledAsync?()
                            case let .failure(error):
                                try await self?._onDisconnectedAsync?(error)
                                try await self?._onCancelledAsync?()
                            }
                        } catch {
                            try? await self?._onErrorAsync?(error, self?.ws)
                        }
                    }
                }
                
                ws.onText { [weak self] (ws, text) in
                    do {
                        try await self?._onTextAsync?(text, ws)
                    } catch {
                        try? await self?._onErrorAsync?(error, ws)
                    }
                }
                
                ws.onBinary { [weak self] (ws, buffer) in
                    do {
                        var data: Data = Data()
                        data.append(contentsOf: buffer.readableBytesView)
                        try await self?._onBinaryAsync?(data, ws)
                    } catch {
                        try? await self?._onErrorAsync?(error, ws)
                    }
                }
            } catch {
                try? await self?._onErrorAsync?(error, self?.ws)
            }
        }
    }

    func disconnect(code: WebSocketErrorCode = .goingAway) async throws {
        try await ws?.close(code: code)
    }
    
    func send(data: Data) async throws {
        try await ws?.send([UInt8](data))
    }
    
    func send(text: String) async throws {
        try await ws?.send(text)
    }
    
    deinit {
        pe("\(Self.self) deinit")
    }
}

