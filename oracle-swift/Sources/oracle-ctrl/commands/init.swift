//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 31.05.2023.
//

import Foundation
import ArgumentParser
import EverscaleClientSwift
import FileUtils
import SwiftExtensionsPack
import adnl_swift
import Logging

extension OracleCtrl {
    public struct Init: AsyncParsableCommand, ValidatorToolOptionsPrtcl {
        
        @OptionGroup var options: ValidatorToolOptions
        
        @Argument(help: "Base file name for files")
        var fileBase: String
        
        public mutating func run() async throws {
            try setClient(options: options)
            try await saveFiles()
        }
        
        private func getKeysByRandomPhrase() async throws -> TSDKKeyPair {
            let mnemonicParams: TSDKParamsOfMnemonicFromRandom = .init(word_count: 12)
            let mnemonic: TSDKResultOfMnemonicFromRandom = try await client.crypto.mnemonic_from_random(mnemonicParams)
            let wordCount: UInt8 = UInt8(mnemonic.phrase.split(separator: " ").count)
            let keysParams: TSDKParamsOfMnemonicDeriveSignKeys = .init(phrase: mnemonic.phrase, word_count: wordCount)
            let keys: TSDKKeyPair = try await client.crypto.mnemonic_derive_sign_keys(keysParams)
            return keys
        }
        
        private func genADNLAddressHash(_ publicKey: String) async throws -> Data {
            return try ADNLAddress(publicKey: publicKey).hash
        }
        
        private func saveFiles() async throws {
            let keys: TSDKKeyPair = try await getKeysByRandomPhrase()
            let addressHash: Data = try await genADNLAddressHash(keys.public)
            let addr: String = try await pwv_getAddress(pubKey: keys.public, wc: 0)
            var parts: [String] = fileBase.split(separator: "/").map { String($0) }
            if parts.count > 1 {
                parts.remove(at: parts.count - 1)
                FileUtils.createFolder(URL(fileURLWithPath: parts.join("/")))
            }
            try FileUtils.writeFile(to: URL(fileURLWithPath: "\(fileBase).pk"), keys.secret.dataFromHex)
            try FileUtils.writeFile(to: URL(fileURLWithPath: "\(fileBase).adnl"), addressHash)
            try FileUtils.writeFile(to: URL(fileURLWithPath: "\(fileBase).addr"), addr.data(using: .utf8))
            logger.notice("Create \(fileBase).pk")
            logger.notice("Create \(fileBase).adnl")
            logger.notice("Create \(fileBase).addr")
        }
    }
}
