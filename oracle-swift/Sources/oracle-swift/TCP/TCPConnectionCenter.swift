//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 28.05.2023.
//

import Foundation
import Vapor
import SwiftExtensionsPackLinux
import adnl_swift

struct TCPRemotePeer {
    let ipAddress: String
    let port: Int
    let publicKey: String
}

class ClientServer {
    private let lock: NSLock = .init()
    private var _cipher: ADNLCipher!
    private var _channel: Channel!
    private var _type: ConnectType
    private var _connected: Bool = false
    private var _pingDelaySec: UInt32
    private var _receivedPong: Bool = false
    private var lastPongTime: UInt = Date().toSeconds()
    var pingDelaySec: UInt32 {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _pingDelaySec
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _pingDelaySec = newValue
        }
    }
    var receivedPong: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _receivedPong
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            if newValue { lastPongTime = Date().toSeconds() }
            _receivedPong = newValue
        }
    }
    var cipher: ADNLCipher {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _cipher
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _cipher = newValue
        }
    }
    var channel: Channel {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _channel
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _channel = newValue
        }
    }
    var type: ConnectType {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _type
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _type = newValue
        }
    }
    var connected: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _connected
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _connected = newValue
        }
    }
    
    init(signer: ADNLCipher? = nil,
         channel: Channel? = nil,
         type: ClientServer.ConnectType,
         connected: Bool = false,
         pingDelaySec: UInt32 = 5
    ) {
        self._cipher = signer
        self._channel = channel
        self._type = type
        self._connected = connected
        self._pingDelaySec = pingDelaySec
        pingWatcher()
    }
    
    func pingWatcher() {
        Thread { [weak self] in
            while true {
                guard let self = self else { return }
                sleep(self.pingDelaySec)
                if self.connected {
                    let now: UInt = Date().toSeconds()
                    let diff: UInt = now - self.lastPongTime
                    if diff >= self.pingDelaySec {
                        self._receivedPong = false
                    }
                    if diff > (self.pingDelaySec * 3) {
                        logger.warning("Ping error. Close Channel")
                        let promise: EventLoopPromise<Void> = self.channel.eventLoop.makePromise()
                        self.channel.close(promise: promise)
                        promise.futureResult.whenComplete { result in
                            self.connected = false
                        }
                    }
                }
            }
        }.start()
    }
}

extension ClientServer {
    enum ConnectType {
        case server
        case client
    }
}

class TCPConnectionCenter {
    private var lock: NSLock = .init()
    private static var lock: NSLock = .init()
    private var _clients: [String: ClientServer] = [:]
    private var _server: Server
    private static var _shared: TCPConnectionCenter!
    
    var clients: [String: ClientServer] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _clients
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _clients = newValue
        }
    }
    var server: Server {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _server
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _server = newValue
        }
    }
    static var shared: TCPConnectionCenter {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let shrd = _shared else { fatalError("TCPConnectionCenter shared object not initialized") }
            return shrd
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _shared = newValue
        }
    }
    
    private init(serverIp: String, serverPort: Int, serverSecret: String, peers: [TCPRemotePeer]) {
        self._clients = [:]
        self._server = Server(ipAddress: serverIp, port: serverPort, secretKey: serverSecret)
    }
    
    static func initialize(serverIp: String, serverPort: Int, serverSecret: String, peers: [TCPRemotePeer]) {
        Self.shared = .init(serverIp: serverIp, serverPort: serverPort, serverSecret: serverSecret, peers: peers)
    }
    
    func run() throws {
        Thread { [weak self] in
            guard let self = self else { return }
            try? server.run()
        }.start()
        
//        Thread { [weak self] in
//            guard let self = self else { return }
//            sleep(1)
////            try? Client(app: self.app, ipAddress: "65.21.141.231", port: 17728, peerPubKey: ADNL_PUB_KEY).run()
//            /// Connect to server
//            try? Client(ipAddress: SERVER_IP, port: SERVER_PORT, peerPubKey: PUBLIC_KEY).run()
//        }.start()
    }
    
    func clientExist(_ key: String) -> Bool {
        clients[key] != nil || server.clients[key] != nil
    }
}


