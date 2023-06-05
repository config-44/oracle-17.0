//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation

class TransactionsSub {
    var ws: WebSocketClient = WebSocketClient(stringURL: "")
    
    init(stringURL: String) {
        self.ws = WebSocketClient(stringURL: stringURL)
    }
}
