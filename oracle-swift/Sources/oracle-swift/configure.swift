//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 25.05.2023.
//

import Foundation
import Vapor

func configure(_ app: Application) async throws {
    let env = try Environment.detect()
    
    /// GET ENV
    try getAllEnvConstants(app)
    
    /// START VAPOR CONFIGURING
    app.http.server.configuration.address = BindAddress.hostname(VAPOR_IP, port: VAPOR_PORT)
    #if os(Linux)
    app.logger.logLevel = .warning
    #else
    app.logger.logLevel = .debug
    #endif
}
