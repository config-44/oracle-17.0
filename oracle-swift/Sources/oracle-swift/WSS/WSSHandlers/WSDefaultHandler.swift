//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation

extension WSSHandler {
    
    class func defaultHandler(service: OracleWSSService, text: String) async throws {
        try await service.parseResponse(text: text)
    }
}
