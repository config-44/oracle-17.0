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
    
    static func routing(text: String, _ wsClient: OracleWSSService) async throws {
        switch text {
        case #"{"type":"connection_ack"}"#:
            break
        case #"{"type":"ka"}"#:
            WSSHandler.pong(wsClient: wsClient)
        default:
            logg(text)
        }
    }
}
