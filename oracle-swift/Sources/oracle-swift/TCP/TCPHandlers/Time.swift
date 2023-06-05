//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 28.05.2023.
//

import Foundation
import NIOCore
import Vapor

extension TCPHandler {
    static func adnlTimeRequest(client: ClientServer) throws {
        let TL_GETTIME = "7af98bb435263e6c95d6fecb497dfd0aa5f031e7d412986b5ce720496db512052e8f2d100cdf068c7904345aad16000000000000"
        let data = try client.cipher.encryptor.adnlSerializeMessage(data: TL_GETTIME.dataFromHex!)
        let buffer = client.channel.allocator.buffer(bytes: data)
        client.channel.writeAndFlush(NIOAny(buffer), promise: nil)
    }
    
    static func adnlTimeParseResponse(client: ClientServer, decryptedData: Data) throws {
        let data = decryptedData[decryptedData.count - 7..<decryptedData.count - 3]
        let unix: UInt32 = .init([UInt8](data), endian: .littleEndian)
        let date: Date = .init(timeIntervalSince1970: TimeInterval(unix))
        client.receivedPong = true
        pe(date)
    }
}

