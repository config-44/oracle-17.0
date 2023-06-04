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
var GQL_WSS_ENDPOINT: String!


func getAllEnvConstants(_ app: Application) throws {
    let env = try Environment.detect()
    app.logger.warning("\(env.name)")
    
    guard let stringPort = Environment.get("VAPOR_PORT"), let variable_1 = Int(stringPort) else {
        fatalError("Set VAPOR_PORT to .env.\(env)")
    }
    VAPOR_PORT = variable_1
    
    guard let variable_2 = Environment.get("VAPOR_IP") else { fatalError("Set VAPOR_IP to .env.\(env)") }
    VAPOR_IP = variable_2
    
    guard let variable_3 = Environment.get("SECRET_KEY") else { fatalError("Set SECRET_KEY to .env.\(env)") }
    SECRET_KEY = variable_3.lowercased()
    
    guard let variable_4 = Environment.get("PUBLIC_KEY") else { fatalError("Set PUBLIC_KEY to .env.\(env)") }
    PUBLIC_KEY = variable_4.lowercased()
    
    guard let variable_5 = Environment.get("SERVER_IP") else { fatalError("Set SERVER_IP to .env.\(env)") }
    SERVER_IP = variable_5
    
    guard let stringPort = Environment.get("SERVER_PORT"), let variable_6 = Int(stringPort) else {
        fatalError("Set SERVER_PORT to .env.\(env)")
    }
    SERVER_PORT = variable_6
    
    guard let variable_7 = Environment.get("GQL_WSS_ENDPOINT") else { fatalError("Set GQL_WSS_ENDPOINT to .env.\(env)") }
    GQL_WSS_ENDPOINT = variable_7
}


