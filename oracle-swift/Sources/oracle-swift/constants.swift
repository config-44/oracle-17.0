//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 26.05.2023.
//

import Foundation
import Vapor


var SECRET_KEY: String!
var VAPOR_PORT: Int!
var VAPOR_IP: String!


func getAllEnvConstants(_ app: Application) throws {
    let env = try Environment.detect()
    app.logger.warning("\(env.name)")
    
    guard let vaporStringPort = Environment.get("vapor_port"), let variable_1 = Int(vaporStringPort) else {
        fatalError("Set vapor_port to .env.\(env)")
    }
    VAPOR_PORT = variable_1
    
    guard let variable_2 = Environment.get("vapor_ip") else { fatalError("Set vapor_ip to .env.\(env)") }
    VAPOR_IP = variable_2
    
    guard let variable_3 = Environment.get("secret") else { fatalError("Set secret to .env.\(env)") }
    SECRET_KEY = variable_3
}


