//
//  File.swift
//
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation
import EverscaleClientSwift

extension SynchronizationService {
    //    {"transactions":[{"id":"94e1d54fcc430c0e235205ae7a0c220bb7a329e1cf9265408fc815d16787ace2","prev_trans_lt":"11710879000002","lt":"11710884000001"}]}
    struct GetLastTransactionModel: Codable {
        var transactions: [Transaction]
        
        struct Transaction: Codable {
            var id: String
            var prev_trans_lt: String
            var lt: String
            var now: UInt
            var out_messages: [OutMessages]
            
            struct OutMessages: Codable {
                var body: String?
                var dst: String
                var msg_type_name: MsgType
            }
            
            enum MsgType: String, Codable {
                case Internal
                case ExtIn
                case ExtOut
            }
        }
    }
    
    func getLastTransactions(service: OracleWSSService, fromUnixTime: UInt, limit: UInt = 100) async throws -> GetLastTransactionModel {
        let query: String = """
    query {
        transactions(
            filter: {
                account_addr: {
                    eq: "\(EYE_CONTRACT!)"
                },
                now: {
                    gt: \(fromUnixTime)
                }
            },
            limit: \(limit),
            orderBy: { path: "now", direction: DESC }
        ) {
            id
            now
            lt(format: DEC)
            prev_trans_lt(format: DEC)
            out_messages { body dst msg_type_name }
        }
    }
"""
        
        let o = try await SDKCLIENT.net.query(TSDKParamsOfQuery(query: query))
        guard let tx = try (o.result.toDictionary()?["data"] as? [String: Any])?.toJSON().toModel(GetLastTransactionModel.self)
        else {
            logg(text: "BAD TX RESPONSE")
            throw OError("BAD TX RESPONSE")
        }
        return tx
    }
}
