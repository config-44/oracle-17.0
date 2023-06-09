//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 26.05.2023.
//

import Foundation
import Vapor
import EverscaleClientSwift
import FileUtils
import SwiftExtensionsPack

var SECRET_KEY: String!
var PUBLIC_KEY: String!
var VAPOR_IP: String!
var VAPOR_PORT: Int!
var SERVER_IP: String!
var SERVER_PORT: Int!
var GQL_WSS_ENDPOINT: String!
var EYE_CONTRACT: String!
var LAST_TX_FILE_DB_PATH: String!
var GQL_HTTPS_ENDPOINT: String!
var SDKCLIENT: TSDKClientModule!
var NEW_ACCOUNTS_TIMEOUT: UInt64!
var REQUEST_BUILDER_TIMEOUT: UInt64!
var FILE_BASE: String!
var BROADCUST_REPEAT: Int!

func getAllEnvConstants(_ app: Application) async throws {
    let env = try Environment.detect()
    app.logger.warning("\(env.name)")
    
    guard let stringPort = Environment.get("VAPOR_PORT"), let variable_1 = Int(stringPort) else {
        fatalError("Set VAPOR_PORT to .env.\(env) in directory \(pathToRootDirectory)")
    }
    VAPOR_PORT = variable_1
    
    guard let variable_2 = Environment.get("VAPOR_IP") else { fatalError("Set VAPOR_IP to .env.\(env)") }
    VAPOR_IP = variable_2
    
    guard let variable_5 = Environment.get("SERVER_IP") else { fatalError("Set SERVER_IP to .env.\(env)") }
    SERVER_IP = variable_5
    
    guard let stringPort = Environment.get("SERVER_PORT"), let variable_6 = Int(stringPort) else {
        fatalError("Set SERVER_PORT to .env.\(env)")
    }
    SERVER_PORT = variable_6
    
    guard let variable_7 = Environment.get("GQL_WSS_ENDPOINT") else { fatalError("Set GQL_WSS_ENDPOINT to .env.\(env)") }
    GQL_WSS_ENDPOINT = variable_7
    
    guard let variable_8 = Environment.get("EYE_CONTRACT") else { fatalError("Set EYE_CONTRACT to .env.\(env)") }
    EYE_CONTRACT = variable_8
    
    guard let variable_9 = Environment.get("LAST_TX_FILE_DB_PATH") else { fatalError("Set LAST_TX_FILE_DB_PATH to .env.\(env)") }
    LAST_TX_FILE_DB_PATH = variable_9
    
    guard let variable_10 = Environment.get("GQL_HTTPS_ENDPOINT") else { fatalError("Set GQL_HTTPS_ENDPOINT to .env.\(env)") }
    GQL_HTTPS_ENDPOINT = variable_10
    
    /// SDK CLIENT
    let networkConfig: TSDKNetworkConfig = .init(server_address: nil,
                                                 endpoints: [GQL_HTTPS_ENDPOINT],
                                                 max_reconnect_timeout: nil,
                                                 message_retries_count: nil,
                                                 message_processing_timeout: nil,
                                                 wait_for_timeout: nil,
                                                 out_of_sync_threshold: nil,
                                                 sending_endpoint_count: nil,
                                                 latency_detection_interval: nil,
                                                 max_latency: nil,
                                                 query_timeout: nil,
                                                 access_key: nil)
    let abiConfig: TSDKAbiConfig = .init(workchain: nil,
                                         message_expiration_timeout: nil,
                                         message_expiration_timeout_grow_factor: nil)
    let config: TSDKClientConfig = .init(network: networkConfig, crypto: nil, abi: abiConfig, boc: nil)
    SDKCLIENT = try TSDKClientModule(config: config)
    
    guard let stringNEW_ACCOUNTS_TIMEOUT = Environment.get("NEW_ACCOUNTS_TIMEOUT"), let variable_11 = UInt64(stringNEW_ACCOUNTS_TIMEOUT) else {
        fatalError("Set NEW_ACCOUNTS_TIMEOUT to .env.\(env)")
    }
    NEW_ACCOUNTS_TIMEOUT = variable_11
    
    /// KEY PAIR
    guard let variable_12 = Environment.get("FILE_BASE") else { fatalError("Set FILE_BASE to .env.\(env)") }
    FILE_BASE = variable_12
    let secreKeyData = try Data(contentsOf: URL(fileURLWithPath: FILE_BASE + ".pk"))
    let pair = try await SDKCLIENT.crypto.nacl_sign_keypair_from_secret_key(TSDKParamsOfNaclSignKeyPairFromSecret(secret: secreKeyData.toHexadecimal))
    SECRET_KEY = secreKeyData.toHexadecimal
    PUBLIC_KEY = pair.public
    
    guard let broadcustPort = Environment.get("BROADCUST_REPEAT"), let variable_13 = Int(broadcustPort) else {
        fatalError("Set BROADCUST_REPEAT to .env.\(env)")
    }
    BROADCUST_REPEAT = variable_13
    
    guard let reqBuilderTimeOutString = Environment.get("REQUEST_BUILDER_TIMEOUT"), let variable_14 = UInt64(reqBuilderTimeOutString) else {
        fatalError("Set REQUEST_BUILDER_TIMEOUT to .env.\(env)")
    }
    REQUEST_BUILDER_TIMEOUT = variable_14
}


