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
    private var _receivedPong: Bool = false
    private var lastPongTime: UInt = Date().toSeconds()
    @Atomic var cipher: ADNLCipher!
    @Atomic var channel: Channel!
    @Atomic var type: ConnectType
    @Atomic var connected: Bool = false
    @Atomic var pingDelaySec: UInt32
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
    
    
    init(signer: ADNLCipher? = nil,
         channel: Channel? = nil,
         type: ClientServer.ConnectType,
         connected: Bool = false,
         pingDelaySec: UInt32 = 5
    ) {
        self.cipher = signer
        self.channel = channel
        self.type = type
        self.connected = connected
        self.pingDelaySec = pingDelaySec
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
    private static var lock: NSLock = .init()
    @Atomic var clients: [String: ClientServer] = [:]
    @Atomic var server: Server
    private static var _shared: TCPConnectionCenter!

    static var shared: TCPConnectionCenter {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let shrd = _shared else {
                let error: String = "TCPConnectionCenter shared object not initialized"
                logg(error, .critical)
                fatalError(error)
            }
            return shrd
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _shared = newValue
        }
    }
    
    private init(serverIp: String, serverPort: Int, serverSecret: String, peers: [TCPRemotePeer]) {
        self.clients = [:]
        self.server = Server(ipAddress: serverIp, port: serverPort, secretKey: serverSecret)
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


