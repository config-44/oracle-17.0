//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation
import GraphQLWS
import class GraphQL.GraphQLJSONEncoder
import WebSocketKit

enum ResponseMessageType: String, Codable {
    case GQL_CONNECTION_ACK = "connection_ack"
    case GQL_CONNECTION_ERROR = "connection_error"
    case GQL_CONNECTION_KEEP_ALIVE = "ka"
    case GQL_DATA = "data"
    case GQL_ERROR = "error"
    case GQL_COMPLETE = "complete"
    case unknown
    
    init(from decoder: Decoder) throws {
        guard let value = try? decoder.singleValueContainer().decode(String.self) else {
            self = .unknown
            return
        }
        self = ResponseMessageType(rawValue: value) ?? .unknown
    }
}

enum RequestMessageType: String, Codable {
    case GQL_CONNECTION_INIT = "connection_init"
    case GQL_START = "start"
    case GQL_STOP = "stop"
    case GQL_CONNECTION_TERMINATE = "connection_terminate"
    case unknown
    
    init(from decoder: Decoder) throws {
        guard let value = try? decoder.singleValueContainer().decode(String.self) else {
            self = .unknown
            return
        }
        self = RequestMessageType(rawValue: value) ?? .unknown
    }
}


struct EncodingErrorResponse: Equatable, Codable, JsonEncodable {
    let type: ResponseMessageType
    let payload: [String: String]
    
    init(_ errorMessage: String) {
        self.type = .GQL_ERROR
        self.payload = ["error": errorMessage]
    }
}

protocol JsonEncodable: Codable {}

extension JsonEncodable {
    /// Converts the object into a JSON string
    /// - Parameter encoder: JSON Encoder used to encode the object into a string
    /// - Returns: The JSON string representation of the object, or an error JSON if not possible
    func toJSON(_ encoder: GraphQLJSONEncoder) -> String {
        let data: Data
        do {
            data = try encoder.encode(self)
        }
        catch {
            return EncodingErrorResponse("Unable to encode response").toJSON(encoder)
        }
        guard let body = String(data: data, encoding: .utf8) else {
            return EncodingErrorResponse("Encoded response can't be cast to string").toJSON(encoder)
        }
        return body
    }
}

public struct ConnectionInitRequest<InitPayload: Codable & Equatable>: Equatable, JsonEncodable {
    var type = RequestMessageType.GQL_CONNECTION_INIT
    let payload: InitPayload
}

public class OracleService {
    static private let ws: WebSocketClient1 = .init(stringURL: GQL_WSS_ENDPOINT)
//    static private let wss: WebSocketMessenger = .init(websocket: WebSocket(channel: Channel, type: .client))
    
    struct A: Codable, Equatable {}
    
    class func start() async throws {
        
        let encoder = GraphQLJSONEncoder()
        
//        let www = WebSocket(channel: <#T##Channel#>, type: <#T##PeerType#>)
        
        
        ws.onConnected { headers in
            pe("onConnected", headers)
            let mess = ConnectionInitRequest(payload: A()).toJSON(encoder)
//            ws.send(text: #"{"type":"connection_init","payload":{}}"#)
//            ws.send(text: #"{"type":"start","payload":{},id:"1"}"#)
            ws.send(text: mess)
//            ws.send(data: #"{"type":"connection_init","payload":{}}"#.data(using: .utf8)!)
        }
        ws.onPing {
            pe("onPing")
        }
        
        ws.onPong {
            pe("onPong")
        }
        
        ws.onCancelled {
            pe("onCancelled")
        }
        
        ws.onDisconnected { reason in
            pe("onDisconnected", reason)
        }
        
        ws.onText { text in
            pe("onText", text)
        }
        
        ws.onBinary { data in
            pe("onBinary", data.toHexadecimal)
        }
        
        ws.connect()
    }
}




/// TEST APOLLO LINUX
import Apollo
import ApolloWebSocket

class Apollo {
  static let shared = Apollo()
    
  /// A web socket transport to use for subscriptions
  private lazy var webSocketTransport: WebSocketTransport = {
    let url = URL(string: "ws://localhost:8080/websocket")!
    let webSocketClient = WebSocket(url: url, protocol: .graphql_transport_ws)
    return WebSocketTransport(websocket: webSocketClient)
  }()
  
  /// An HTTP transport to use for queries and mutations
  private lazy var normalTransport: RequestChainNetworkTransport = {
    let url = URL(string: "http://localhost:8080/graphql")!
    return RequestChainNetworkTransport(interceptorProvider: DefaultInterceptorProvider(store: self.store), endpointURL: url)
  }()

  /// A split network transport to allow the use of both of the above
  /// transports through a single `NetworkTransport` instance.
  private lazy var splitNetworkTransport = SplitNetworkTransport(
    uploadingNetworkTransport: self.normalTransport,
    webSocketNetworkTransport: self.webSocketTransport
  )

  /// Create a client using the `SplitNetworkTransport`.
  private(set) lazy var client = ApolloClient(networkTransport: self.splitNetworkTransport, store: self.store)

  /// A common store to use for `normalTransport` and `client`.
  private lazy var store = ApolloStore()
}
