//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 27.05.2023.
//

import Foundation
import NIOCore
import adnl_swift
import Vapor

extension TCPHandler {
    
    static func handshakeRequest(client: ClientServer) throws {
        let handshake: Data = try ADNLHandshake.adnlHandshake(keys: client.cipher.keys,
                                                              params: client.cipher.params,
                                                              address: client.cipher.address)
        let buffer: ByteBuffer = client.channel.allocator.buffer(bytes: handshake)
        client.channel.writeAndFlush(NIOAny(buffer), promise: nil)
    }
    
    static func handshakeResponse(context: ChannelHandlerContext, server: Server, data: Data) {
        do {
            let cipher: ADNLCipher = try ADNLHandshake.adnlHandshakeAssets(data, secretKey: SECRET_KEY)
            let data = try cipher.encryptor.adnlSerializeMessage(data: Data())
            let buffer = context.channel.allocator.buffer(data: data)
            let promise: EventLoopPromise<Void> = context.channel.eventLoop.makePromise()
            context.channel.writeAndFlush(NIOAny(buffer), promise: promise)
            promise.futureResult.whenComplete { result in
                switch result {
                case .success(_):
                    do {
                        try server.clients[context.channel.ipAddressWithHost()] = .init(signer: cipher,
                                                                                        channel: context.channel,
                                                                                        type: .server,
                                                                                        connected: true)
                    } catch {
                        errorPrint(error)
                    }
                case let .failure(error):
                    errorPrint(error)
                }
            }
        } catch {
            context.channel.close(promise: nil)
        }
    }
}
