//
//  File.swift
//
//
//  Created by Oleh Hudeichuk on 05.06.2023.
//

import Foundation
import SwiftExtensionsPack
import FileUtils
import EverscaleClientSwift
import BigInt



class SynchronizationService {
    static let shared: SynchronizationService = .init()
    @Atomic private var lastCheckTime: UInt?
    private let fileUtilsActor: FileUtilsActor = .init()
    private let transactionQueue: RequestTransactionQueueActor = .init()
    private init() {}
    
    func startWatcher(service: OracleWSSService) async throws {
        Task.detached { [weak self] in
            while self != nil {
                do {
                    try await Task.sleep(nanoseconds: 1 * UInt64(pow(10, 9) as Double))
                    try await self?.process(service: service)
                } catch {
                    logg(text: String(describing: error))
                }
            }
        }
    }
    
    private func getLastTransactionTime(service: OracleWSSService) throws -> UInt {
        var start: UInt = Date().toSeconds() - 8600 * 113
        if let lastCheckTime = lastCheckTime {
            start = lastCheckTime
        } else {
            if FileUtils.fileExist(LAST_TX_FILE_DB_PATH) {
                let content = try FileUtils.readFile(URL(fileURLWithPath: LAST_TX_FILE_DB_PATH))
                let model: GetLastTransactionModel.Transaction = try content.trimmingCharacters(in: .whitespacesAndNewlines).toModel(GetLastTransactionModel.Transaction.self)
                if model.now > start { start = model.now }
            }
        }
        return start
    }
    
    private func saveLastTransaction(_ tx: GetLastTransactionModel.Transaction) async throws {
        try await fileUtilsActor.writeToFile(to: LAST_TX_FILE_DB_PATH, tx.tryToJson())
    }
    
    private func checkFirst32Bites(_ number: Int) -> Bool {
        number == 0xf0e109c0
    }
    #warning("test")
    @Atomic var testCounter: Float = 0
    private func process(service: OracleWSSService) async throws {
        let startTime: UInt = try getLastTransactionTime(service: service)
        let transactions: [GetLastTransactionModel.Transaction] = try await getLastTransactions(service: service,
                                                                                                fromUnixTime: startTime).transactions
        
        #warning("test")
        testCounter += 1
        if Float(Int(testCounter / 10)) == testCounter / 10 {
            logg(text: "I am okay 😌")
        }
        if transactions.count > 0 {
            logg(text: "Wow 😯 I found \(transactions.count) transactions 😋")
        }
        if let trnsaction = transactions.first {
            lastCheckTime = trnsaction.now
        }
        
        for i in 0..<transactions.count {
            let transaction: GetLastTransactionModel.Transaction = transactions[transactions.count - (1 + i)]
            await transactionQueue.append(transaction)
            if
                let message = transaction.out_messages.first,
                let body = message.body,
                message.msg_type_name == .Internal,
                transaction.out_messages.count == 1
            {
                let out: AnyValue = try await SDKCLIENT.abi.decode_boc(TSDKParamsOfDecodeBoc(params: [
                    .init(name: "op", type: "uint32"),
                    .init(name: "r1", type: "cell"),
                    .init(name: "queryCell", type: "cell"),
                ],
                                                                                             boc: body,
                                                                                             allow_partial: true)
                ).data
                
                guard
                    let number: Int = Int(out.toDictionary()?["op"] as? String ?? ""),
                    let queryCell: String = out.toDictionary()?["queryCell"] as? String,
                    checkFirst32Bites(number)
                else {
                    continue
                }
                
                Task.detached { [weak self] in
                    do {
                        try await self?.process_next_step(service: service, addr: message.dst, queryCell: queryCell)
                        
                        if (try? await self?.transactionQueue.isFirstReq(transaction)) ?? false {
                            try await self?.saveLastTransaction(transaction)
                            await self?.transactionQueue.delete(transaction)
                        }
                    } catch {
                        logg(makeError(OError(error)), .warning)
                    }
                }
            }
        }
    }
    
    private func getDataFromRequestAddr(service: OracleWSSService, reqAddr: String) async throws -> [String: Any?]? {
        let account = try await waitAccountActive(service: service, addr: reqAddr)
        guard let data = account?.data else {
            logg(.warning, text: "Contract Data not found. Addr: \(reqAddr)")
            return nil
        }
        let out = try await SDKCLIENT.abi.decode_boc(TSDKParamsOfDecodeBoc(
            params: [
                .init(name: "_inited", type: "bool"),
                .init(name: "_eye_address_0", type: "uint11"),
                .init(name: "_eye_address_1", type: "uint256"),
                .init(name: "_client_addr_0", type: "uint11"),
                .init(name: "_client_addr_1", type: "uint256"),
                .init(name: "_equery_hash", type: "uint256"),
                .init(name: "_oracle_list", type: "map(uint7,cell)"),
                .init(name: "_builder_id", type: "uint7"),
                .init(name: "_result", type: "optional(cell)"),
                .init(name: "_votes", type: "optional(cell)"),
                .init(name: "_votes_count", type: "uint7"),
                .init(name: "_finished", type: "bool"),
                .init(name: "_oracle_count", type: "uint7"),
                .init(name: "_salt", type: "uint64"),
            ],
            boc: data,
            allow_partial: true)
        ).data.toDictionary()
        return out
    }
    
    private func process_next_step(service: OracleWSSService, addr: String, queryCell: String) async throws {
        let out = try await getDataFromRequestAddr(service: service, reqAddr: addr)
        guard
            let inited = out?["_inited"] as? Bool,
            let eye_address_0 = UInt16(out?["_eye_address_0"] as? String ?? ""),
            let eye_address_1 = (out?["_eye_address_1"] as? String)?.remove0x.dataFromHex,
            let client_addr_0 = UInt16(out?["_client_addr_0"] as? String ?? ""),
//            let client_addr_1 = (out?["_client_addr_1"] as? String)?.remove0x.dataFromHex,
            let equery_hash = (out?["_equery_hash"] as? String)?.remove0x.dataFromHex,
            let oracle_list = out?["_oracle_list"] as? [String: String],
            let builder_id = UInt8(out?["_builder_id"] as? String ?? ""),
            let result = out?["_result"] as? String?,
//            let votes = out?["_votes"] as? [String: String],
//            let votes_count = UInt8(out?["_votes_count"] as? String ?? ""),
            let finished = out?["_finished"] as? Bool
//            let oracle_count = UInt8(out?["_oracle_count"] as? String ?? "")
        else {
            logg(.warning, text: "INVALID PARSE REQ DATA. Addr: \(addr)")
            return
        }
        if finished { return }
        if !inited {
            logg(.critical, text: "NOT INITED REQ. Addr: \(addr)")
            return
        }
        if eye_address_0 & 0xFF != 0 {
            logg(.critical, text: "eye_address_0: 8 bit is present. Addr: \(addr)")
            return
        }
        let eye_address: String = "0:" + eye_address_1.toHexadecimal.lowercased()
        if eye_address != EYE_CONTRACT.lowercased() {
            logg(.critical, text: "eye_address \(eye_address) not equal to \(addr)")
            return
        }
        if client_addr_0 & 0xFF != 0 {
            logg(.critical, text: "client_addr_0: 8 bit is present. Addr: \(addr)")
            return
        }
        let queryCellHash: String = try await SDKCLIENT.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: queryCell)).hash
        if queryCellHash != equery_hash.toHexadecimal {
            logg(.critical, text: "equery_hash not equal. Addr: \(addr)")
            return
        }
        var oracleListParsed: [UInt8: Oracle] = .init()
        var oraclsListAssignedPubKey: [UInt8: Oracle] = .init()
        for (key, value) in oracle_list {
            let out = try await SDKCLIENT.abi.decode_boc(TSDKParamsOfDecodeBoc(
                params: [
                    .init(name: "pub_key", type: "uint256"),
                    .init(name: "adnl_addr", type: "uint256"),
                    .init(name: "stake", type: "varuint16"),
                ],
                boc: value,
                allow_partial: false)).data.toDictionary()
            guard
                let pub_key = (out?["pub_key"] as? String)?.remove0x.dataFromHex,
                let adnl_addr = (out?["adnl_addr"] as? String)?.remove0x.dataFromHex,
                let stake = BigInt(out?["stake"] as? String ?? ""),
                let keyUint8 = UInt8(key)
            else {
                logg(.critical, text: "CAN NOT PARSE ORACLE IN ORACLE LIST. Addr: \(addr)")
                continue
            }
            oracleListParsed[keyUint8] = Oracle(pubKey: pub_key, adnlAddr: adnl_addr, stake: stake)
            if pub_key == (try PUBLIC_KEY.remove0x.dataFromHexThrowing()) {
                oraclsListAssignedPubKey[keyUint8] = Oracle(pubKey: pub_key, adnlAddr: adnl_addr, stake: stake)
            }
        }
        if oraclsListAssignedPubKey.keys.isEmpty {
            logg(.info, text: "CURRENT PUB_KEY NOT FOUND. Addr: \(addr)")
            return
        }
        if oraclsListAssignedPubKey.keys.count != 1 {
            logg(.critical, text: "DOUBLE SIGN FOR ONE TASK. Addr: \(addr)")
            return
        }
        /// #IF СОВЕТ БОРИСА 🫠
        let builder = TvmCellBuilder()
        builder.storeCellRefFromBoc(value: queryCell)
        let queryCellByBoris = try await SDKCLIENT.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: builder.build()))
        let queryStringFromBorisCell: AnyValue = try await SDKCLIENT.abi.decode_boc(TSDKParamsOfDecodeBoc(
            params: [
                .init(name: "query", type: "string")
            ],
            boc: queryCellByBoris.boc,
            allow_partial: true)
        ).data
        guard let query = queryStringFromBorisCell.toDictionary()?["query"] as? String else {
            logg(.warning, text: "Query not found in \(queryStringFromBorisCell.toJSON())")
            return
        }
        logg(.info, text: "New query: \"\(query)\" from \(addr)")
        /// #ENDIF
        let oracleId = oraclsListAssignedPubKey.first!.key
        if oracleId == builder_id {
            try await goAsBuilder(url: query, id: oracleId, reqAddr: addr)
        } else {
            try await goAsConfirmer(service: service, url: query, id: oracleId, reqAddr: addr)
        }
    }
    
    private func goAsBuilder(url: String, id: UInt8, reqAddr: String) async throws {
        logg(.info, text: "Builder id: \(id) \(reqAddr)")
        let data = try await Net.sendRequest(url: url, method: "GET").data
        /// #IF Обратный совет Бориса 🤡
        let encodedBoc = try await SDKCLIENT.abi.encode_boc(TSDKParamsOfAbiEncodeBoc(
            params: [
                .init(name: "dataString", type: "string")
            ],
            data: [
                "dataString": String(data: data, encoding: .utf8)
            ].toAnyValue()))
        
        let stringCell = try await SDKCLIENT.abi.decode_boc(TSDKParamsOfDecodeBoc(
            params: [
                .init(name: "dataStringCell", type: "cell")
            ],
            boc: encodedBoc.boc,
            allow_partial: false)).data.toDictionary()
        guard let stringCellBoc = stringCell?["dataStringCell"] as? String else {
            throw makeError(OError("DANGER WARNING 44"))
        }
        /// #ENDIF
        let resultBuilder: TvmCellBuilder = .init()
        resultBuilder.storeUInt(value: BigInt(id), size: 7)
        resultBuilder.storeCellRefFromBoc(value: stringCellBoc)
        let signedResult = try await signCellBuilder(SDKCLIENT, resultBuilder, SECRET_KEY.dataFromHexThrowing())
        
        let be: TvmCellBuilder = .init()
        /// SUBMIT_RESULT
        be.storeUInt(value: BigInt(0xde1c6a17), size: 32)
        be.storeBytes(value: signedResult)
        be.append(builder: resultBuilder)
        
        let body = try await SDKCLIENT.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: be.build())).boc
        let extMessage = try await SDKCLIENT.boc.encode_external_in_message(TSDKParamsOfEncodeExternalInMessage(dst: reqAddr, body: body)).message
        for _ in 0..<BROADCUST_REPEAT {
            logg(.info, text: "Builder send external id: \(id) \(reqAddr)")
            let resultSend = try await SDKCLIENT.processing.send_message(TSDKParamsOfSendMessage(message: extMessage, send_events: false))
        }
    }
    
    private func goAsConfirmer(service: OracleWSSService, url: String, id: UInt8, reqAddr: String) async throws {
        logg(.info, text: "Confirmer id: \(id) \(reqAddr)")
        let resultBoc = try await waitRequestBuilderResult(service: service, addr: reqAddr)
        let data = try await Net.sendRequest(url: url, method: "GET").data
        /// #IF Обратный совет Бориса 🤡
        let encodedBoc = try await SDKCLIENT.abi.encode_boc(TSDKParamsOfAbiEncodeBoc(
            params: [
                .init(name: "dataString", type: "string")
            ],
            data: [
                "dataString": String(data: data, encoding: .utf8)
            ].toAnyValue()))
        
        let stringCell = try await SDKCLIENT.abi.decode_boc(TSDKParamsOfDecodeBoc(
            params: [
                .init(name: "dataStringCell", type: "cell")
            ],
            boc: encodedBoc.boc,
            allow_partial: false)).data.toDictionary()
        guard let stringCellBoc = stringCell?["dataStringCell"] as? String else {
            throw makeError(OError("DANGER WARNING 44"))
        }
        /// #ENDIF
        guard let resultBoc = resultBoc else {
            throw makeError(OError("resultBoc not found"))
        }
        let resultBocHash: String = try await SDKCLIENT.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: resultBoc)).hash
        let stringCellHash: String = try await SDKCLIENT.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: stringCellBoc)).hash
        if resultBocHash != stringCellHash {
            logg(.warning, text: "Result from remote server is not equal from req contract")
            return
        }
        let confimBuilder: TvmCellBuilder = .init()
        confimBuilder.storeUInt(value: BigInt(id), size: 7)
        let signedConfimBuilder = try await signCellBuilder(SDKCLIENT, confimBuilder, SECRET_KEY.dataFromHexThrowing())
        
        let be: TvmCellBuilder = .init()
        /// CONFIRM_RESULT
        be.storeUInt(value: BigInt(0x9a6ff4ff), size: 32)
        be.storeBytes(value: signedConfimBuilder)
        be.append(builder: confimBuilder)
        
        let body = try await SDKCLIENT.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: be.build())).boc
        let extMessage = try await SDKCLIENT.boc.encode_external_in_message(TSDKParamsOfEncodeExternalInMessage(dst: reqAddr, body: body)).message
        for _ in 0..<BROADCUST_REPEAT {
            logg(.info, text: "Confirmer send external id: \(id) \(reqAddr)")
            let resultSend = try await SDKCLIENT.processing.send_message(TSDKParamsOfSendMessage(message: extMessage, send_events: false))
        }
//        let out = try await SDKCLIENT.processing.wait_for_transaction(TSDKParamsOfWaitForTransaction(message: extMessage, shard_block_id: resultSend.shard_block_id, send_events: false))
    }
    
    private func waitRequestBuilderResult(service: OracleWSSService,
                                          addr: String,
                                          timeOut: UInt64 = REQUEST_BUILDER_TIMEOUT
    ) async throws -> String? {
        let waitActiveActor: WaitActiveActor = .init()
        return try await withCheckedThrowingContinuation { conn in
            Task.detached { [weak self] in
                let start: UInt64 = UInt64(Date().toSeconds())
                while await !waitActiveActor.cancelled {
                    do {
                        let out = try await self?.getDataFromRequestAddr(service: service, reqAddr: addr)
                        if let result = out?["_result"] as? String {
                            await waitActiveActor.cancel()
                            conn.resume(returning: result)
                        } else if UInt64(Date().toSeconds()) - start < timeOut {
                            let checkInterval: Double = 0.6
                            try await Task.sleep(nanoseconds: UInt64(checkInterval * pow(10, 9) as Double))
                        } else {
                            await waitActiveActor.cancel()
                            conn.resume(returning: nil)
                        }
                    } catch {
                        await waitActiveActor.cancel()
                        conn.resume(throwing: makeError(OError(String(describing: error))))
                    }
                }
            }
        }
    }
}

extension SynchronizationService {
    
    struct Oracle {
        var pubKey: Data
        var adnlAddr: Data
        var stake: BigInt
    }
    
    actor RequestTransactionQueueActor {
        var queue: [GetLastTransactionModel.Transaction] = []
        var queueTxLtSet: Set<String> = .init()
        
        func addToStart(_ reqTx: GetLastTransactionModel.Transaction) {
            if !queueTxLtSet.contains(reqTx.lt) {
                queue.insert(reqTx, at: 0)
            }
        }
        
        func append(_ reqTx: GetLastTransactionModel.Transaction) {
            if !queueTxLtSet.contains(reqTx.lt) {
                queue.append(reqTx)
            }
        }
        
        func delete(_ reqTx: GetLastTransactionModel.Transaction) {
            queueTxLtSet.remove(reqTx.lt)
            queue = queue.filter { $0.lt != reqTx.lt }
        }
        
        func isFirstReq(_ tx: GetLastTransactionModel.Transaction) throws -> Bool {
            guard let txReq = queue.first else {
                throw makeError(OError("Transaction request with lt \(tx.lt) not found in queue. Because queu is empty."))
            }
            return txReq.lt == tx.lt
        }
    }
}


