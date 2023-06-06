//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation
import SwiftExtensionsPack
import FileUtils

class SynchronizationService {
    static let shared: SynchronizationService = .init()
    @Atomic private var lastCheckTime: UInt = Date().toSeconds()
    @Atomic private var service: OracleWSSService!
    private init() {}
    
    func start(service: OracleWSSService) {
        
    }
    
    private func getLastTransactionTime(service: OracleWSSService) throws -> UInt {
        var start: UInt = Date().toSeconds() - 8600 * 3
        if FileUtils.fileExist(LAST_TX_FILE_DB_PATH) {
            let content = try FileUtils.readFile(URL(fileURLWithPath: LAST_TX_FILE_DB_PATH))
            let model: GetLastTransactionModel.Transaction = try content.trimmingCharacters(in: .whitespacesAndNewlines).toModel(GetLastTransactionModel.Transaction.self)
            if model.now > start { start = model.now }
        }
        return start
    }
    
    private func firstStart(service: OracleWSSService) async throws {
        let startTime: UInt = try getLastTransactionTime(service: service)
        let transactions = try await getLastTransactions(service: service, fromUnixTime: startTime).transactions
        if let trnsaction = transactions.last {
            lastCheckTime = trnsaction.now
        }
    }
}

