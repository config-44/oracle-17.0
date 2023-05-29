//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 28.05.2023.
//

import Foundation
import NIOCore

extension Channel {
    func ipAddressWithHost() throws -> String {
        guard let ipAddress = remoteAddress?.ipAddress,
              let port = remoteAddress?.port
        else {
            throw OError("RemoteAddress not found")
        }
        return "\(ipAddress):\(port)"
    }
}
