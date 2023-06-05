//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation

extension WSSHandler {
    class func pong(service: OracleWSSService) {
        service.lastPingUnixTime = Date().toSeconds()
    }
}
