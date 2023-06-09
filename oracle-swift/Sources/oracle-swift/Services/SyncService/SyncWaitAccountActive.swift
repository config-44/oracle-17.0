//
//  File.swift
//
//
//  Created by Oleh Hudeichuk on 07.06.2023.
//

import Foundation
import SwiftExtensionsPack
import EverscaleClientSwift


extension SynchronizationService {
    //    {"transactions":[{"id":"94e1d54fcc430c0e235205ae7a0c220bb7a329e1cf9265408fc815d16787ace2","prev_trans_lt":"11710879000002","lt":"11710884000001"}]}
    struct WaitAccountActiveModel: Codable {
        var accounts: [Account]?
        
        struct Account: Codable {
            var id: String
            var data: String?
        }
    }
    
    actor WaitActiveActor {
        var cancelled: Bool = false
        
        func cancel() {
            cancelled = true
        }
    }
    
    func waitAccountActive(service: OracleWSSService,
                           addr: String,
                           timeOut: UInt64 = NEW_ACCOUNTS_TIMEOUT
    ) async throws -> WaitAccountActiveModel.Account? {
        let query: String = """
    query {
        accounts(
            filter: {
                id: {
                    eq: "\(addr)"
                }
            }
        ) {
            id
            data
        }
    }
"""
        
        let waitAccountActiveActor: WaitActiveActor = .init()
        return try await withCheckedThrowingContinuation { conn in
            Task.detached {
                let start: UInt64 = UInt64(Date().toSeconds())
                while await !waitAccountActiveActor.cancelled {
                    do {
                        let out = try await SDKCLIENT.net.query(TSDKParamsOfQuery(query: query))
                        guard let accounts = try (out.result.toDictionary()?["data"] as? [String: Any])?.toJSON().toModel(WaitAccountActiveModel.self)
                        else {
                            logg(text: "BAD ACCOUNT RESPONSE")
                            continue
                        }
                        if let account = (accounts.accounts ?? []).first, account.data != nil {
                            await waitAccountActiveActor.cancel()
                            conn.resume(returning: account)
                        } else if UInt64(Date().toSeconds()) - start < timeOut {
                            let checkInterval: Double = 0.6
                            try await Task.sleep(nanoseconds: UInt64(checkInterval * pow(10, 9) as Double))
                        } else {
                            await waitAccountActiveActor.cancel()
                            conn.resume(returning: nil)
                        }
                    } catch {
                        await waitAccountActiveActor.cancel()
                        conn.resume(throwing: makeError(OError(String(describing: error))))
                    }
                }
            }
        }
    }
}
