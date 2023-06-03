//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 03.06.2023.
//

import Foundation
import ArgumentParser
import EverscaleClientSwift
import FileUtils
import SwiftExtensionsPack
import adnl_swift
import Logging
import BigInt

extension OracleCtrl {
    public struct Master: AsyncParsableCommand, ValidatorToolOptionsPrtcl {
        
        @OptionGroup var options: ValidatorToolOptions
        
        @Argument(help: "Base file name for files")
        var fileBase: String
        
        @Argument(help: "Proposal ID")
        var id: UInt64
        
        @Argument(wrappedValue: "eye-master.body", help: "Output file name")
        var saveFile: String
        
        public mutating func run() async throws {
            try setClient(options: options)
            try await saveFiles()
        }
        
        private func saveFiles() async throws {
            let secret: Data = try Data(contentsOf: URL(fileURLWithPath: "\(fileBase).pk"))
            let proposalCell: TvmCellBuilder = .init()
            proposalCell.storeUInt(value: BigInt(id), size: 64)
            
            let signature: String = try await signCellBuilder(client, proposalCell, secret)
            let queryid: UInt64 = try await queryId(client, proposalCell)
            
            let bodyCell: TvmCellBuilder = .init()
            bodyCell.storeUInt(value: 0x00000004, size: 32)
            bodyCell.storeUInt(value: BigInt(queryid), size: 64)
            bodyCell.storeBytes(value: signature)
            bodyCell.append(builder: proposalCell)
            /// SAVE
            let bodyBoc: Data = try await client.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: bodyCell.build())).boc.dataFromHexOrBase64()
            try FileUtils.writeFile(to: URL(fileURLWithPath: "\(saveFile).boc"), bodyBoc)
        }
    }
}
