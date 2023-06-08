//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 03.06.2023.
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
    public struct Info: AsyncParsableCommand, ValidatorToolOptionsPrtcl {
        
        @OptionGroup var options: ValidatorToolOptions
        
        @Argument(help: "Address of contract")
        var contractAddress: String
        
        public mutating func run() async throws {
            try setClient(options: options)
            try await parse()
        }
        
        private func parse() async throws {
            let abi: [[String: String]] = [
                ["name":"_master_key","type":"uint256"],
                ["name":"_proposal_timeout","type":"uint32"],
                ["name":"_total_stake","type":"varuint16"],
                ["name":"_min_stake","type":"varuint16"],
                ["name":"_max_stake","type":"varuint16"],
                ["name":"_min_voting_reward","type":"varuint16"],
                ["name":"_total_rewards","type":"varuint16"],
                ["name":"_proposals_count","type":"uint8"],
                ["name":"_proposal_list","type":"map(uint64,cell)"],
                ["name":"_active_proposers","type":"optional(cell)"],
                ["name":"_current_list","type":"map(uint7,cell)"],
                ["name":"_req_code","type":"cell"]
            ]
            var abiParams: [TSDKAbiParam] = .init()
            for param in abi {
                abiParams.append(.init(name: param["name"]!, type: param["type"]!))
            }
            pe(try await client.version().version)
            pe(try await client.net.get_endpoints().endpoints)
            
            let paramsOfQueryCollection: TSDKParamsOfQueryCollection = .init(collection: "accounts",
                                                                             filter: [
                                                                                "id": [
                                                                                    "eq": contractAddress
                                                                                ]
                                                                             ].toAnyValue(),
                                                                             result: "data")
            
            let result = try await client.net.query_collection(paramsOfQueryCollection)
            var data: String = ""
            if let anyResult = result.result.map({ $0.toAny() }).first as? [String: Any] {
                if let resultBoc: String = anyResult["data"] as? String {
                    data = resultBoc
                } else {
                    throw makeError(TSDKClientError("Receive result, but Boc not found"))
                }
            } else {
                throw makeError(TSDKClientError("Boc not found"))
            }
            let out = try await client.abi.decode_boc(TSDKParamsOfDecodeBoc(params: abiParams,
                                                                            boc: data,
                                                                            allow_partial: true))
            logger.notice("\("Proposal_list".uppercased())")
            var consoleInfo: [[String: Any]] = .init()
            for (key, value) in ((out.data.toDictionary()?["_proposal_list"] as? [String: String]) ?? [:]) {
                let out = try await client.abi.decode_boc(TSDKParamsOfDecodeBoc(params: [.init(name: "prefix", type: "uint8")], boc: value, allow_partial: true))
                let pfx = UInt8(out.data.toDictionary()?["prefix"] as! String)
                if (pfx == 0x01) {
                    let out = try await client.abi.decode_boc(TSDKParamsOfDecodeBoc(
                        params: [
                            .init(name: "prefix", type: "uint8"),
                            .init(name: "pubKey", type: "uint256"),
                            .init(name: "adnl", type: "uint256"),
                            .init(name: "stake", type: "varuint16")
                        ],
                        boc: value,
                        allow_partial: true))
                
                    consoleInfo.append([
                        "pidx": key,
                        "valid_until": "\(UInt64(key)! >> 32) (~\(BigInt(UInt(key)! >> 32) - BigInt(Date().toSeconds())) sec)",
                        "stake": BigInt(out.data.toDictionary()?["stake"] as! String)?.nanoCrystalToCrystal ?? "",
                        "pubKey": out.data.toDictionary()?["pubKey"] as! String,
                        "adnl": out.data.toDictionary()?["adnl"] as! String,
                    ])
                } else if (pfx == 0x02) {
                    consoleInfo.append([key: "0x02..."])
                }
            }
            logger.notice("\(consoleInfo.toAnyValue().toJSON())")
            
            logger.notice("\("Current_list".uppercased())")
            consoleInfo = []
            for (key, value) in ((out.data.toDictionary()?["_current_list"] as? [String: String]) ?? [:]) {
                let out = try await client.abi.decode_boc(TSDKParamsOfDecodeBoc(
                    params: [
                        .init(name: "pubKey", type: "uint256"),
                        .init(name: "adnl", type: "uint256"),
                        .init(name: "stake", type: "varuint16")
                    ],
                    boc: value,
                    allow_partial: true))
                consoleInfo.append([
                    "id": key,
                    "stake": BigInt(out.data.toDictionary()?["stake"] as! String)?.nanoCrystalToCrystal ?? "",
                    "pubKey": out.data.toDictionary()?["pubKey"] as! String,
                    "adnl": out.data.toDictionary()?["adnl"] as! String,
                ])
            }
            logger.notice("\(consoleInfo.toAnyValue().toJSON())")
        }
    }
}
