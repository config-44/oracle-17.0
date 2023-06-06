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
        }
    }
    
    func getLastTransactions(service: OracleWSSService, fromUnixTime: UInt) async throws -> GetLastTransactionModel {
        let query: String = """
    query getMissing($address: String!, $now: Float!) {
        transactions(
            filter: {
                account_addr: {
                    eq: $address
                },
                now: {
                    gt: $now
                }
            },
            limit: 1,
            orderBy: { path: "now", direction: DESC }
        ) {
            id
            now
            lt(format: DEC)
            prev_trans_lt(format: DEC)
        }
    }
"""
        
        let request = GQLRequest(id: service.getQueryId(),
                                 type: .start,
                                 payload: .init(variables: ["address": EYE_CONTRACT, "now": fromUnixTime].toAnyValue(),
                                                query: query))
        let out = try await service.send(id: request.id!, request: request)
        return try out.toJson.toModel(GetLastTransactionModel.self)
    }
}
