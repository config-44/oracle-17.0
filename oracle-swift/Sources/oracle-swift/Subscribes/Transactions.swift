//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation

class TransactionsSub {
    var ws: WebSocketClient1 = WebSocketClient1(stringURL: "")
    
    init(stringURL: String) {
        self.ws = WebSocketClient1(stringURL: stringURL)
    }
}
