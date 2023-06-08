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
    @Atomic private var service: OracleWSSService!
    private let fileUtilsActor: FileUtilsActor = .init()
    private init() {}
    
    func startWatcher(service: OracleWSSService) async throws {
        //        let l = try await waitAccountActive(service: service, addr: "0:cab2cb50ec7fc6fdea51bbb146ad77db3e7652c6b051ae8b95d0fd146fbac094")
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
    
    private func process(service: OracleWSSService) async throws {
        let startTime: UInt = try getLastTransactionTime(service: service)
        let transactions: [GetLastTransactionModel.Transaction] = try await getLastTransactions(service: service,
                                                                                                fromUnixTime: startTime).transactions
        
        if let trnsaction = transactions.first {
            lastCheckTime = trnsaction.now
        }
        
        for i in 0..<transactions.count {
            let transaction: GetLastTransactionModel.Transaction = transactions[transactions.count - (1 + i)]
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
                
                #warning("ADD THREADS")
                try await process_next_step(service: service, addr: message.dst, queryCell: queryCell)
                
                
            }
            
            //            Task.detached {
            //                try await self.saveLastTransaction(transaction)
            //            }
        }
    }
    
    private func process_next_step(service: OracleWSSService, addr: String, queryCell: String) async throws {
        let account = try await waitAccountActive(service: service, addr: addr)
        guard let data = account?.data else {
            logg(.warning, text: "Contract Data not found. Addr: \(addr)")
            return
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
//                .init(name: "_votes", type: "map(uint7,cell)"),
                .init(name: "_votes_count", type: "uint7"),
                .init(name: "_finished", type: "bool"),
                .init(name: "_oracle_count", type: "uint7"),
            ],
            boc: data,
            allow_partial: true)
        ).data.toDictionary()
        pe(out)
        return;
        guard
            let inited = out?["_inited"] as? Bool,
            let eye_address_0 = UInt16(out?["_eye_address_0"] as? String ?? ""),
            let eye_address_1 = (out?["_eye_address_1"] as? String)?.remove0x.dataFromHex,
            let client_addr_0 = UInt16(out?["_client_addr_0"] as? String ?? ""),
            let client_addr_1 = (out?["_client_addr_1"] as? String)?.remove0x.dataFromHex,
            let equery_hash = (out?["_equery_hash"] as? String)?.remove0x.dataFromHex,
            let oracle_list = out?["_oracle_list"] as? [String: String],
            let builder_id = UInt8(out?["_builder_id"] as? String ?? ""),
            let result = out?["_result"] as? String?,
            let votes = out?["_votes"] as? [String: String],
            let votes_count = UInt8(out?["_votes_count"] as? String ?? ""),
            let finished = out?["_finished"] as? Bool,
            let oracle_count = UInt8(out?["_oracle_count"] as? String ?? "")
        else {
            logg(.warning, text: "INVALID PARSE REQ DATA. Addr: \(addr)")
            return
        }
        if finished { return }
        if !inited {
            logg(.critical, text: "NOT INITED REQ. Addr: \(addr)")
            #warning("return return")
//            return
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
            try await goAsConfirmer(url: query, id: oracleId, reqAddr: addr, resultBoc: result)
        }
    }
    
    private func goAsBuilder(url: String, id: UInt8, reqAddr: String) async throws {
        let data = try await Net.sendRequest(url: url, method: "GET").data
        /// #IF Обрфтный совет Бориса 🤡
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
        let resultSend = try await SDKCLIENT.processing.send_message(TSDKParamsOfSendMessage(message: extMessage, send_events: false))
        pe(resultSend)
    }
    
    private func goAsConfirmer(url: String, id: UInt8, reqAddr: String, resultBoc: String?) async throws {
        let data = try await Net.sendRequest(url: url, method: "GET").data
        /// #IF Обрфтный совет Бориса 🤡
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
        let resultSend = try await SDKCLIENT.processing.send_message(TSDKParamsOfSendMessage(message: extMessage, send_events: false))
        let out = try await SDKCLIENT.processing.wait_for_transaction(TSDKParamsOfWaitForTransaction(message: extMessage, shard_block_id: resultSend.shard_block_id, send_events: false))
        pe(resultSend)
        pe(out)
    }
}

extension SynchronizationService {
    
    struct Oracle {
        var pubKey: Data
        var adnlAddr: Data
        var stake: BigInt
    }
}
