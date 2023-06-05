//
//  OracleRouter.swift
//  
//
//  Created by Oleh Hudeichuk on 27.05.2023.
//

import Foundation
import NIOCore
import SwiftExtensionsPack

enum TCPRouter: UInt32 {
    case adnlTime = 262964246
    case ping = 1
    case pong = 2
    
    static func getRoute(client: ClientServer, decryptedData: Data) throws {
        let id: UInt32 = .init(decryptedData[0..<4].bytes, endian: .littleEndian)
        guard let route = Self.init(rawValue: id) else {
            throw OError("Route not found")
        }
        switch route {
        case .adnlTime:
            try TCPHandler.adnlTimeParseResponse(client: client, decryptedData: decryptedData)
        case .ping:
            try TCPHandler.pong(client: client)
        case .pong:
            client.receivedPong = true
        }
    }
    
    static func makeRequestWithRoute(_ route: Self, data: Data) -> Data {
        let id: Data = .init(route.rawValue.toBytes(endian: .littleEndian, count: 4))
        var result: Data = .init(id)
        result.append(data)
        return result
    }
}
