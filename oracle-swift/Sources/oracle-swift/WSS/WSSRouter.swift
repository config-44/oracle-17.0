//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation
import NIOCore
import SwiftExtensionsPack

class WSSRouter {
    
    static func routing(text: String, _ service: OracleWSSService) async throws {
        switch text {
        case #"{"type":"connection_ack"}"#:
            try await WSSHandler.parseTransactions(service: service)
        case #"{"type":"ka"}"#:
            WSSHandler.pong(service: service)
        default:
//            logg("default: \(text)")
            try await WSSHandler.defaultHandler(service: service, text: text)
        }
    }
}
