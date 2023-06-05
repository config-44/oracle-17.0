//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 25.05.2023.
//

import Foundation
import NIOCore
import NIOPosix
import launch
import Vapor
import adnl_swift

class Server {
    let ipAddress: String
    let port: Int
    @Atomic var clients: [String: ClientServer] = [:]
    
    init(ipAddress: String, port: Int, secretKey: String) {
        self.ipAddress = ipAddress
        self.port = port
    }
    
    func run() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount * 2)
        let bootstrap = ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        // Set the handlers that are appled to the accepted Channels
            .childChannelInitializer { channel in
                // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                channel.pipeline.addHandler(BackPressureHandler()).flatMap { v in
                    return channel.pipeline.addHandler(TCPServerHandler(server: self))
                }
            }
        // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        // Bootstrap
        let server = try bootstrap.bind(host: ipAddress, port: port).wait()
        try server.closeFuture.wait()
    }
}




private final class TCPServerHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    private var server: Server
    
    init(server: Server) {
        self.server = server
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
    
    public func channelActive(context: ChannelHandlerContext) {
        print("Client connected to \(context.remoteAddress!)")
        do {
            #if DEBUG
            try server.clients[context.channel.ipAddressWithHost()] = .init(type: .server)
            #else
            if try TCPConnectionCenter.shared.clientExist(context.channel.ipAddressWithHost()) {
                try server.clients[context.channel.ipAddressWithHost()] = .init(type: .server)
            } else {
                logger.info("Client exists")
            }
            #endif
        } catch {
            errorPrint(error)
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            // As we are not really interested getting notified on success or failure we just pass nil as promise to
            // reduce allocations.
            pe("SERVER - READ")
            var byteBuffer: ByteBuffer = self.unwrapInboundIn(data)
            guard let readableBytes = byteBuffer.readBytes(length: byteBuffer.readableBytes) else {
                logger.warning("TCP - readableBytes not found")
                return
            }
            let data: Data = .init(readableBytes)
            /// HANDSHAKE
            guard let client = try server.clients[context.channel.ipAddressWithHost()] else {
                throw OError("Client not found")
            }
            
            if !client.connected {
                TCPHandler.handshakeResponse(context: context, server: server, data: data)
            }
            
            if client.connected {
                let decryptedData = try client.cipher.decryptor.adnlDeserializeMessage(data: data)
                /// ROUTING
                try TCPRouter.getRoute(client: client, decryptedData: decryptedData)
            }
        } catch {
            errorPrint(error)
        }
    }
    
    // Flush it out. This can make use of gathering writes if multiple buffers are pending
    public func channelReadComplete(context: ChannelHandlerContext) {
        pe("context.flush()")
        context.flush()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        //        self.app.logger.warning("\(OError(String(describing: error)).localizedDescription)")
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}
//
