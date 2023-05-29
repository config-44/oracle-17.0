//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 18.05.2023.
//

import Foundation
import NIOCore
import NIOPosix
import SwiftExtensionsPack
import adnl_swift
import Vapor

final class Client {
    private let app: Application
    private let ipAddress: String
    private let port: Int
    private let peerPubKey: String
    private let lock: NSLock = .init()
    private var _clientServer: ClientServer
    var clientServer: ClientServer {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _clientServer
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _clientServer = newValue
        }
    }
    
    init(app: Application, ipAddress: String, port: Int, peerPubKey: String) throws {
        self.app = app
        self.ipAddress = ipAddress
        self.port = port
        self.peerPubKey = peerPubKey
        let tempPrivateKey = "0cd07f83cdab454b02b6533861fe6555acf3f8ef9e1c8e5086a5e2297d1942e2"
        let signer: ADNLCipher = try .init(serverSecret: tempPrivateKey, peerPubKey: peerPubKey, mode: .client)
        self._clientServer = ClientServer(app: app,
                                          signer: signer,
                                          type: .client)
    }
    
    func run() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        
        let bootstrap = ClientBootstrap(group: group)
        // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(TCPClientHandler(app: self.app, client: self))
            }
        
        let channel: Channel = try bootstrap.connect(host: ipAddress, port: port).wait()
        try channel.closeFuture.wait()
    }
    
    deinit {
        pe("deinit \(Self.self)")
    }
}

private final class TCPClientHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    private let app: Application
    private var client: Client
    
    init(app: Application, client: Client) {
        self.app = app
        self.client = client
    }
    
    public func channelActive(context: ChannelHandlerContext) {
        do {
            client.clientServer.channel = context.channel
            try TCPConnectionCenter.shared.clients[context.channel.ipAddressWithHost()] = client.clientServer
            /// SEND HANDSHAKE
            try TCPController.handshakeRequest(client: client.clientServer)
        } catch {
            self.app.logger.critical("\(OError(String(describing: error)).localizedDescription)")
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            var byteBuffer: ByteBuffer = self.unwrapInboundIn(data)
            guard let readableBytes = byteBuffer.readBytes(length: byteBuffer.readableBytes) else {
                app.logger.warning("TCP - readableBytes not found")
                return
            }
            let data: Data = .init(readableBytes)
            ///================
//            pe("CLIENT READ - DATA BEFORE DECRYPT: ", data.toHexadecimal)
//            let decrData: Data = try client.clientServer.signer.decryptor.update(data)
//            pe("CLIENT decrData", decrData.toHexadecimal)
//            pe("CLIENT decrData SHA 256: ", decrData.sha256().toHexadecimal)
            ///================
            let decryptedData = try client.clientServer.cipher.decryptor.adnlDeserializeMessage(data: data)
            
            /// ROUTING
            if client.clientServer.connected {
                try TCPRouter.getRoute(client: client.clientServer, decryptedData: decryptedData)
            } else {
                if decryptedData.count == 0 {
                    client.clientServer.connected = true
                    TCPController.ping(client: client.clientServer)
                } else {
                    self.app.logger.warning("Handshake failed")
                    context.channel.close(promise: nil)
                }
            }
        } catch {
            errorPrint(self.app, error)
        }
    }
    
    public func channelRegistered(context: ChannelHandlerContext) {
        pe("channelRegistered")
        context.fireChannelRegistered()
    }
    
    public func channelUnregistered(context: ChannelHandlerContext) {
        pe("channelUnregistered")
        context.fireChannelUnregistered()
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        pe("channelInactive")
        context.fireChannelInactive()
    }
    
    public func channelWritabilityChanged(context: ChannelHandlerContext) {
        pe("channelWritabilityChanged")
        context.fireChannelWritabilityChanged()
    }
    
    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        pe("userInboundEventTriggered")
        context.fireUserInboundEventTriggered(event)
    }
    
    public func channelReadComplete(context: ChannelHandlerContext) {
        pe("context.flush()")
        context.flush()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.app.logger.warning("\(OError(String(describing: error)).localizedDescription)")
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
    
    deinit {
        pe("deinit \(Self.self)")
        client.clientServer.channel.close(promise: nil)
        pe(TCPConnectionCenter.shared.clients)
        _ = try? TCPConnectionCenter.shared.clients.removeValue(forKey: client.clientServer.channel.ipAddressWithHost())
        pe(TCPConnectionCenter.shared.clients)
    }
}
