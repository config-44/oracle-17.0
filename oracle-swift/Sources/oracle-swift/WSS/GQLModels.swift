//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation
import SwiftExtensionsPack

//{
//    "id": "1",
//    "type": "start",
//    "payload": {
//        "variables": {},
//        "extensions": {},
//        "operationName": null,
//        "query": "query {}"
//    }
//}
struct GQLRequest: Codable {
    var id: String?
    var type: GQLRequestType
    var payload: GQLRequestPayload?
    
    enum GQLRequestType: String, Codable {
        case connection_init
        case start
        case stop
        case connection_terminate
        case unknown
    }
    
    struct GQLRequestPayload: Codable {
        var variables: AnyValue = [String: Any]().toAnyValue()
        var extensions: AnyValue = [String: Any]().toAnyValue()
        var operationName: String?
        var query: String?
    }
}

//        {"type":"data","id":"1","payload":{"data":{"transactions":[{"id":"94e1d54fcc430c0e235205ae7a0c220bb7a329e1cf9265408fc815d16787ace2","lt":"11710884000001","prev_trans_lt":"11710879000002"}]}}}
        
        
//        {
//            "type":"data",
//            "id":"1",
//            "payload":{
//                "errors":[
//                    {
//                        "message": "Variable \"$address\" got invalid value 1; String cannot represent a non string value: 1",
//                        "locations":[
//                            {"line":1,"column":18}
//                        ],
//                        "extensions":{
//                            "code":"INTERNAL_SERVER_ERROR"
//                        }
//                    }
//                ]
//            }
//        }


struct GQLResponse: Codable {
    var id: String
    var type: GQLResponseType
    var payload: GQLResponsePayload?
    
    enum GQLResponseType: String, Codable {
        case connection_ack
        case connection_error
        case ka
        case data
        case error
        case complete
        case unknown
    }
    
    struct GQLResponsePayload: Codable {
        var data: AnyValue?
        var errors: [Errors]?
        
        struct Errors: Codable {
            var message: String
            var locations: AnyValue?
            var extensions: AnyValue?
        }
    }
}
