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

final class WebSocketClient1 {
    
    var url: URL
    private var eventLoopGroup: EventLoopGroup
    @Atomic var ws: WebSocket?
    
    init(stringURL: String, coreCount: Int = System.coreCount) {
        url = URL(string: stringURL)!
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: coreCount)
    }
    
    private var _onConnected: ((_ headers: Result<[String : String]?, Error>) -> Void)?
    private var _onDisconnected: ((_ reason: String?) -> Void)?
    private var _onCancelled: (() -> Void)?
    private var _onText: ((_ text: String) -> Void)?
    private var _onBinary: ((_ data: Data) -> Void)?
    private var _onPing: (() -> Void)?
    private var _onPong: (() -> Void)?
    
    func onConnected(_ handler: @escaping ((_ headers: Result<[String : String]?, Error>) -> Void)) {
        _onConnected = handler
    }
    
    func onDisconnected(_ handler: @escaping ((_ reason: String?) -> Void)) {
        _onDisconnected = handler
    }
    
    func onCancelled(_ handler: @escaping (() -> Void)) {
        _onCancelled = handler
    }
    
    func onText(_ handler: @escaping ((_ text: String) -> Void)) {
        _onText = handler
    }
    
    func onBinary(_ handler: @escaping ((_ data: Data) -> Void)) {
        _onBinary = handler
    }
    
    func onPing(_ handler: @escaping (() -> Void)) {
        _onPing = handler
    }
    
    func onPong(_ handler: @escaping (() -> Void)) {
        _onPong = handler
    }
    
    func connect(headers: [String: String]? = nil) {
        
        var httpHeaders: HTTPHeaders = .init()
        headers?.forEach({ (name, value) in
            httpHeaders.add(name: name, value: value)
        })
        let promise: EventLoopPromise<Void> = eventLoopGroup.any().makePromise(of: Void.self)
        
        WebSocket.connect(to: url.absoluteString,
                          headers: httpHeaders,
                          on: eventLoopGroup
        ) { ws in
            self.ws = ws
            
            ws.onPing { [weak self] (ws) in
                self?._onPing?()
            }
            
            ws.onPong { [weak self] (ws) in
                self?._onPong?()
            }
            
            ws.onClose.whenComplete { [weak self] (result) in
                switch result {
                case .success:
                    self?._onDisconnected?(nil)
                    self?._onCancelled?()
                case let .failure(error):
                    self?._onDisconnected?(String(describing: error))
                    self?._onCancelled?()
                }
            }
            
            ws.onText { (ws, text) in
                self._onText?(text)
            }
            
            ws.onBinary { (ws, buffer) in
                var data: Data = Data()
                data.append(contentsOf: buffer.readableBytesView)
                self._onBinary?(data)
            }
            
        }.cascade(to: promise)
        
        promise.futureResult.whenSuccess { [weak self] (_) in
            guard let self = self else { return }
            self._onConnected?(.success(nil))
        }
        
        promise.futureResult.whenFailure { [weak self] error in
            guard let self = self else { return }
            self._onConnected?(.failure(error))
        }
    }
    
    func disconnect() {
        ws?.close(promise: nil)
    }
    
    func send(data: Data) {
        ws?.send([UInt8](data))
    }
    
    func send(data: Data, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.any().makePromise(of: Void.self)
        if let promise = promise, let ws = ws {
            ws.send([UInt8](data), promise: promise)
            promise.futureResult.whenComplete { (_) in
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    func send(text: String) {
        ws?.send(text)
    }
    
    func send(text: String, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.any().makePromise(of: Void.self)
        if let promise = promise, let ws = ws {
            ws.send(text, promise: promise)
            promise.futureResult.whenComplete { (_) in
                completion?()
            }
        } else {
            completion?()
        }
    }
}
