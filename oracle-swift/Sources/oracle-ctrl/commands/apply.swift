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
import BigInt

extension OracleCtrl {
    public struct Apply: AsyncParsableCommand, ValidatorToolOptionsPrtcl {
        
        @OptionGroup var options: ValidatorToolOptions
        
        @Argument(help: "Base file name for files")
        var fileBase: String
        
        @Argument(help: "Oracle stake in grams")
        var stake: String
        
        @Argument(help: "Eye smc voting reward in grams")
        var votingReward: String
        
        @Argument(wrappedValue: "eye-apply.body", help: "Output file name")
        var saveFile: String
        
        public mutating func run() async throws {
            try setClient(options: options)
            
            let stakeAmount: BigInt = stake.toNanoCrystals
            let votingRewardAmount: BigInt = votingReward.toNanoCrystals
            
            logger.notice("Loading private key from \(fileBase).pk")
            let secret: Data = try Data(contentsOf: URL(fileURLWithPath: "\(fileBase).pk"))
            logger.notice("Loading ADNL address from \(fileBase).adnl")
            let adnlAddr: String = try Data(contentsOf: URL(fileURLWithPath: "\(fileBase).adnl")).toHexadecimal
            
            let publicKey: String = try await client.crypto.nacl_sign_keypair_from_secret_key(TSDKParamsOfNaclSignKeyPairFromSecret(secret: secret.toHexadecimal)).public
            
            logger.notice("Using public key:\t\(publicKey)")
            logger.notice("Using ADNL address:\t\(adnlAddr)")
            
            /// <b 0x01 8 u, pub-key B, adnl-addr B, stake Gram, voting-reward Gram, b>
            let prposal: TvmCellBuilder = .init()
            prposal.storeUInt(value: 0x01, size: 8)
            prposal.storeBytes(value: publicKey)
            prposal.storeBytes(value: adnlAddr)
            try prposal.storeGrams(value: stakeAmount)
            try prposal.storeGrams(value: votingRewardAmount)
            let boc: TSDKResultOfEncodeBoc = try await client.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: prposal.build()))
            let hash: String = try await client.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: boc.boc)).hash
            guard let base64 = hash.dataFromHex?.base64EncodedString() else { throw TSDKClientError("Bad hash \(hash)") }
            let signedBoc: TSDKResultOfSign = try await client.crypto.sign(TSDKParamsOfSign(unsigned: base64,
                                                                                            keys: TSDKKeyPair(public: publicKey,
                                                                                                              secret: secret.toHexadecimal)))
            /// uint32 – 0x00000002
            /// uint64 – (timestamp << 32) + (proposal_hash & 0xFFFFFFFF)
            /// bytes – sign
            /// ref – proposal
            let body: TvmCellBuilder = .init()
            body.storeUInt(value: 0x00000002, size: 32)
            guard let partOfHash = hash.dataFromHex?[0..<4] else { throw TSDKClientError("Bad data") }
            let queryid: UInt64 = try await queryId(client, prposal)
            body.storeUInt(value: BigInt(queryid), size: 64)
            body.storeBytes(value: signedBoc.signature)
            body.storeCellRef(builder: prposal.build())
            /// SAVE
            let bodyBoc: Data = try await client.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: body.build())).boc.dataFromHexOrBase64()
            try FileUtils.writeFile(to: URL(fileURLWithPath: "\(saveFile).boc"), bodyBoc)
            logger.notice("Saved eye message body to file: \(saveFile).boc")
        }
    }
}

