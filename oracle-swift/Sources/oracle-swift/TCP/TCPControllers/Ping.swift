//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 28.05.2023.
//

import Foundation
import NIOCore
import Vapor

extension TCPController {
    
    static func ping(client: ClientServer) throws {
        var data = TCPRouter.makeRequestWithRoute(.ping, data: Data())
        data = try client.cipher.encryptor.adnlSerializeMessage(data: data)
        let buffer = client.channel.allocator.buffer(bytes: data)
        pe("ping")
        client.channel.writeAndFlush(NIOAny(buffer), promise: nil)
    }
    
    static func pong(client: ClientServer) throws {
        var data = TCPRouter.makeRequestWithRoute(.pong, data: Data())
        data = try client.cipher.encryptor.adnlSerializeMessage(data: data)
        let buffer = client.channel.allocator.buffer(bytes: data)
        pe("pong")
        client.receivedPong = true
        client.channel.writeAndFlush(NIOAny(buffer), promise: nil)
    }
}
