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
        let response: GQLResponse = try service.parseResponse(text: text)
        switch response.type {
        case .connection_ack:
            try await SynchronizationService.shared.startWatcher(service: service)
        case .ka:
            WSSHandler.pong(service: service)
        default:
//            logg(text: "default: \(text)")
            try await WSSHandler.defaultHandler(service: service, response: response)
        }
    }
}
