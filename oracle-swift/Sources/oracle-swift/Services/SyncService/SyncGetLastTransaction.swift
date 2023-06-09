//
//  File.swift
//
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation


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
    query getMissing($address: String!, $now: Float!, $limit: Int!) {
        transactions(
            filter: {
                account_addr: {
                    eq: $address
                },
                now: {
                    gt: $now
                }
            },
            limit: $limit,
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
        
        let request = GQLRequest(id: await service.requestsActor.nextQueryID(),
                                 payload: .init(variables: [
                                    "address": EYE_CONTRACT,
                                    "now": fromUnixTime,
                                    "limit": limit,
                                 ].toAnyValue(),
                                                query: query))
        
        let out = try await service.send(id: request.id!, request: request)
        return try out.toJson.toModel(GetLastTransactionModel.self)
    }
}
