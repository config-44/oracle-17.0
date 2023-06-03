//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 25.08.2021.
//

import Foundation
import EverscaleClientSwift
import SwiftExtensionsPack
import BigInt

var pathToRootDirectory: String {
    /// Please, set custom working directory to project folder for your xcode scheme. This is necessary for the relative path "./" to the project folders to work.
    /// You may change it with the xcode edit scheme menu.
    /// Or inside file path_to_ton_sdk/.swiftpm/xcode/xcshareddata/xcschemes/TonSDK.xcscheme
    /// set to tag "LaunchAction" absolute path to this library with options:
    /// useCustomWorkingDirectory = "YES"
    /// customWorkingDirectory = "/path_to_ton_sdk"
    let workingDirectory: String = "./"
    if !FileManager.default.fileExists(atPath: workingDirectory) {
        fatalError("\(workingDirectory) directory is not exist")
    }
    return workingDirectory
}

func readAbi(_ relativeFilePath: String) -> AnyValue {
    var abiJSON: String = pathToRootDirectory + "/\(relativeFilePath)"
    if relativeFilePath[#"^\/"#] {
        abiJSON = relativeFilePath
    } else {
        abiJSON = pathToRootDirectory + "/\(relativeFilePath)"
    }
    var abiText: String = .init()
    DOFileReader.readFile(abiJSON) { (line) in
        abiText.append(line)
    }
    guard let any = abiText.toAnyValue() else { fatalError("AbiJSON Not Parsed From File") }
    
    return any
}

func readTvc(_ relativeFilePath: String) -> Data {
    let tvc: String = pathToRootDirectory + "/\(relativeFilePath)"
    guard let data = FileManager.default.contents(atPath: tvc) else { fatalError("tvc not read") }
    
    return data
}

//func sdk(endpoints: [String]? = nil) throws -> TSDKClientModule {
//    let defaultEndpoints: [String] = [
//        "https://rustnet1.ton.dev",
//        "https://rustnet2.ton.dev"
//    ]
//    var config: TSDKClientConfig = .init()
//    config.network = TSDKNetworkConfig(endpoints: endpoints ?? defaultEndpoints)
//    return try TSDKClientModule(config: config)
//}

func paramsJsonToDictionary(_ params: String) throws -> [String: Any?] {
    guard let data: Data = params.data(using: .utf8)
    else { fatalError("Bad params json, it must be valid json") }
    var dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any?]
    dict = booleaFix(dict) as? [String: Any?]
    
    return dict ?? [:]
}

func paramsJsonToDictionary(_ params: String) throws -> Any? {
    guard let data: Data = params.data(using: .utf8)
    else { fatalError("Bad params json, it must be valid json") }
    var dict: Any? = try JSONSerialization.jsonObject(with: data, options: [])
    dict = booleaFix(dict)
    
    return dict
}


private func booleaFix(_ data: Any?) -> Any? {
    if var temp = data as? [Any?] {
        for (index, value) in temp.enumerated() {
            temp[index] = booleaFix(value)
        }
        return temp
    } else if var temp = data as? [String: Any] {
        for key in temp.keys {
            temp[key] = booleaFix(temp[key])
        }
        return temp
    } else {
        if let data = data as? NSNumber, type(of: data) == type(of: NSNumber(value: true)) {
            if data == NSNumber(value: 1) {
                return true
            } else {
                return false
            }
        } else {
            return data
        }
    }
}


public func signCellBuilder(_ client: TSDKClientModule, _ cellBuilder: TvmCellBuilder, _ secret: Data) async throws -> String {
    let publicKey: String = try await client.crypto.nacl_sign_keypair_from_secret_key(TSDKParamsOfNaclSignKeyPairFromSecret(secret: secret.toHexadecimal)).public
    let boc: TSDKResultOfEncodeBoc = try await client.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: cellBuilder.build()))
    let hash: String = try await client.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: boc.boc)).hash
    guard let base64 = hash.dataFromHex?.base64EncodedString() else { throw TSDKClientError("Bad hash \(hash)") }
    let signedBoc: TSDKResultOfSign = try await client.crypto.sign(TSDKParamsOfSign(unsigned: base64,
                                                                                    keys: TSDKKeyPair(public: publicKey,
                                                                                                      secret: secret.toHexadecimal)))
    return signedBoc.signature
}


public func queryId(_ client: TSDKClientModule, _ cell: TvmCellBuilder) async throws -> UInt64 {
    let boc: TSDKResultOfEncodeBoc = try await client.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: cell.build()))
    let hash: String = try await client.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: boc.boc)).hash
    guard let partOfHash = hash.dataFromHex?[0..<4] else { throw TSDKClientError("Bad data") }
    return (UInt64(Date().toSeconds()) << 32) + (UInt64(UInt32(partOfHash.bytes, endian: .bigEndian)) & 0xFFFFFFFF)
}
