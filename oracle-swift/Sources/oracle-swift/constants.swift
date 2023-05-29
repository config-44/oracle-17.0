//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 26.05.2023.
//

import Foundation
import Vapor


var SECRET_KEY: String!
var PUBLIC_KEY: String!
var VAPOR_IP: String!
var VAPOR_PORT: Int!
var SERVER_IP: String!
var SERVER_PORT: Int!


func getAllEnvConstants(_ app: Application) throws {
    let env = try Environment.detect()
    app.logger.warning("\(env.name)")
    
    guard let stringPort = Environment.get("vapor_port"), let variable_1 = Int(stringPort) else {
        fatalError("Set vapor_port to .env.\(env)")
    }
    VAPOR_PORT = variable_1
    
    guard let variable_2 = Environment.get("vapor_ip") else { fatalError("Set vapor_ip to .env.\(env)") }
    VAPOR_IP = variable_2
    
    guard let variable_3 = Environment.get("secret") else { fatalError("Set secret to .env.\(env)") }
    SECRET_KEY = variable_3.lowercased()
    
    guard let variable_4 = Environment.get("public") else { fatalError("Set public to .env.\(env)") }
    PUBLIC_KEY = variable_4.lowercased()
    
    guard let variable_5 = Environment.get("server_ip") else { fatalError("Set server_ip to .env.\(env)") }
    SERVER_IP = variable_5
    
    guard let stringPort = Environment.get("server_port"), let variable_6 = Int(stringPort) else {
        fatalError("Set server_port to .env.\(env)")
    }
    SERVER_PORT = variable_6
}


