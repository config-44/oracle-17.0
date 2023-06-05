//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation
import SwiftExtensionsPack

extension WSSHandler {
    class func parseTransactions(service: OracleWSSService) async throws {
        let query: String = """
        query getMissing($address: String!) {
            transactions(
                filter: {
                    account_addr: {
                        eq: $address
                    }
                },
                limit: 1,
                orderBy: { path: "lt", direction: DESC }
            ) {
                id
                lt(format: DEC)
                prev_trans_lt(format: DEC)
            }
        }
"""
        
        //        {"type":"data","id":"1","payload":{"data":{"transactions":[{"id":"94e1d54fcc430c0e235205ae7a0c220bb7a329e1cf9265408fc815d16787ace2","lt":"11710884000001","prev_trans_lt":"11710879000002"}]}}}
        
        
        //        {"type":"data","id":"1","payload":{"errors":[{"message":"Variable \"$address\" got invalid value 1; String cannot represent a non string value: 1","locations":[{"line":1,"column":18}],"extensions":{"code":"INTERNAL_SERVER_ERROR"}}]}}
        
        let request = GQLRequest(id: service.getQueryId(),
                                 type: .start,
                                 payload: .init(variables: ["address": EYE_CONTRACT].toAnyValue(),
                                                query: query))
        let out = try await service.send(id: request.id!, request: request)
        pe("AAAAA", out.toJson)
    }
}
