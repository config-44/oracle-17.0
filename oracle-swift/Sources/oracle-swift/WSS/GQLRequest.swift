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
        var variables: [String: AnyValue]?
        var extensions: [String: AnyValue]?
        var operationName: String?
        var query: String?
    }
}
