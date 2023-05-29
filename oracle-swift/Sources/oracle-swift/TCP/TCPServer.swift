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
    let app: Application
    let ipAddress: String
    let port: Int
    var _clients: [String: ClientServer] = [:]
    private let lock: NSLock = .init()
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
    
    init(app: Application, ipAddress: String, port: Int, secretKey: String) {
        self.app = app
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
                    return channel.pipeline.addHandler(TCPServerHandler(app: self.app, server: self))
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
    private let app: Application
    private var server: Server
    
    init(app: Application, server: Server) {
        self.app = app
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
            try server.clients[context.channel.ipAddressWithHost()] = .init(app: app, type: .server)
        } catch {
            errorPrint(app, error)
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            // As we are not really interested getting notified on success or failure we just pass nil as promise to
            // reduce allocations.
            pe("SERVER - READ")
            var byteBuffer: ByteBuffer = self.unwrapInboundIn(data)
            guard let readableBytes = byteBuffer.readBytes(length: byteBuffer.readableBytes) else {
                app.logger.warning("TCP - readableBytes not found")
                return
            }
            let data: Data = .init(readableBytes)
            /// HANDSHAKE
            guard let client = try server.clients[context.channel.ipAddressWithHost()] else {
                throw OError("Client not found")
            }
            
            if !client.connected {
                TCPController.handshakeResponse(app: app, context: context, server: server, data: data)
            }
            
            if client.connected {
                let decryptedData = try client.cipher.decryptor.adnlDeserializeMessage(data: data)
                pe(decryptedData.toHexadecimal)
            }
            
            //        ///parse handshake
            //        let handshake = try! ADNLHandshake.adnlParseHandshake(data)
            //        let receivedClientPublic = handshake.senderPubKey.toHexadecimal
            //        pe("SERVER - receiver_address or shortLocalNodeId\n", handshake.shortLocalNodeId.toHexadecimal)
            //        pe("SERVER - receivedClientPublic", receivedClientPublic)
            //        pe("SERVER - Proof CheckSum SHA-256(aes_params)", handshake.checkSum.toHexadecimal)
            //        pe("SERVER - Payload E(aes_params)", handshake.encryptedData.toHexadecimal)
            //
            //        let signer: TCPCipher = try! .init(serverSecret: SECRET_KEY, peerPubKey: receivedClientPublic)
            ////        let signer: TCPSigner = try! .init(serverSecret: SECRET_KEY, peerPubKey: PUBLIC_KEY)
            //        let signerDecryptedData = try! signer.decryptor.update(handshake.encryptedData)
            //        pe("SERVER - decrypted payload - 0", signerDecryptedData.toHexadecimal)
            //        pe("SERVER - decrypted payload SHA 256 - 0", signerDecryptedData.sha256().toHexadecimal)
            //
            //
            //        let hhhh = try! ADNLHandshake.adnlHandshakeAssets(data, secretKey: SECRET_KEY)
            ////        let g = try! hhhh.encryptor.adnlSerializeMessage(data: Data([1,2,3,4]))
            //        let g = try! hhhh.encryptor.adnlSerializeMessage(data: Data())
            //        pe("SERVER SENT", g.toHexadecimal)
            //        let b = context.channel.allocator.buffer(data: g)
            //        context.writeAndFlush(NIOAny(b), promise: nil)
            
            //        let gggg = try! signer.decryptor.adnlDeserializeMessage(data: handshake.encryptedData)
            //        gggg.toHexadecimal
            //        pe("GGGG", gggg.toHexadecimal)
            //        pe("GGGG", gggg.sha256().toHexadecimal)
            //
            //        pe("sender pubkey", pub)
            //        pe("server toHexadecimal", data.toHexadecimal)
            //        let decryptedData = try client.clientServer.signer.decryptor.adnlDeserializeMessage(data: data)
            //        context.writeAndFlush(data, promise: nil)
        } catch {
            errorPrint(app, error)
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
