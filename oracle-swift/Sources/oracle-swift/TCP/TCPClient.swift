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
    private let ipAddress: String
    private let port: Int
    private let peerPubKey: String
    @Atomic var clientServer: ClientServer
    
    init(ipAddress: String, port: Int, peerPubKey: String) throws {
        self.ipAddress = ipAddress
        self.port = port
        self.peerPubKey = peerPubKey
//        let tempPrivateKey = "0cd07f83cdab454b02b6533861fe6555acf3f8ef9e1c8e5086a5e2297d1942e2"
        let signer: ADNLCipher = try .init(peerPubKey: peerPubKey, mode: .client)
        self.clientServer = ClientServer(signer: signer, type: .client)
    }
    
    func run() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        
        let bootstrap = ClientBootstrap(group: group)
        // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(TCPClientHandler(client: self))
            }
        
        let channel: Channel = try bootstrap.connect(host: ipAddress, port: port).wait()
        pingMaker()
        try channel.closeFuture.wait()
    }
    
    func pingMaker() {
        Thread { [weak self] in
            while true {
                guard let self = self else { pe("exit ping"); return }
                sleep(self.clientServer.pingDelaySec)
                do {
                    try TCPHandler.ping(client: self.clientServer)
                } catch {
                    errorPrint(error)
                }
            }
        }.start()
    }
    
    deinit {
        pe("deinit \(Self.self)")
    }
}

private final class TCPClientHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    private var client: Client
    
    init(client: Client) {
        self.client = client
    }
    
    public func channelActive(context: ChannelHandlerContext) {
        do {
            client.clientServer.channel = context.channel
            try TCPConnectionCenter.shared.clients[context.channel.ipAddressWithHost()] = client.clientServer
            /// SEND HANDSHAKE
            try TCPHandler.handshakeRequest(client: client.clientServer)
        } catch {
            logger.critical("\(OError(String(describing: error)).localizedDescription)")
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            var byteBuffer: ByteBuffer = self.unwrapInboundIn(data)
            guard let readableBytes = byteBuffer.readBytes(length: byteBuffer.readableBytes) else {
                logger.warning("TCP - readableBytes not found")
                return
            }
            let data: Data = .init(readableBytes)
            let decryptedData = try client.clientServer.cipher.decryptor.adnlDeserializeMessage(data: data)
            
            /// ROUTING
            if client.clientServer.connected {
                try TCPRouter.getRoute(client: client.clientServer, decryptedData: decryptedData)
            } else {
                if decryptedData.count == 0 {
                    client.clientServer.connected = true
                    try TCPHandler.ping(client: client.clientServer)
                } else {
                    logger.warning("Handshake failed")
                    context.channel.close(promise: nil)
                }
            }
        } catch {
            errorPrint(error)
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
        logger.warning("\(OError(String(describing: error)).localizedDescription)")
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
