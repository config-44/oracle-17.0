//
//  File.swift
//
//
//  Created by Oleh Hudeichuk on 25.08.2021.
//

import Foundation
import ArgumentParser
import EverscaleClientSwift
import FileUtils
import SwiftExtensionsPack

extension OracleCtrl {
    public struct Run: ParsableCommand, ValidatorToolOptionsPrtcl {

        @OptionGroup var options: ValidatorToolOptions

        @Option(name: [.long, .customShort("d")], help: "Account address")
        var addr: String

        @Option(name: [.long, .customShort("m")], help: "Calling method")
        var method: String

        @Option(name: [.long, .customShort("j")], help: "Params")
        var paramsJSON: String = "{}"

        @Option(name: [.long, .customShort("a")], help: "Path to abi file")
        var abiPath: String
        
        @Option(name: [.long, .customShort("b")], help: "Boc")
        var boc: String = "none"

        public func run() throws {
            if boc == "none" {
                try makeResult()
            } else {
                try makeResultWithBoc()
            }
        }

        @discardableResult
        func makeResult() throws -> String {
            try setClient(options: options)
            var functionResult: String = ""
            let group: DispatchGroup = .init()
            group.enter()

            let paramsOfWaitForCollection: TSDKParamsOfWaitForCollection = .init(collection: "accounts",
                                                                                 filter: [
                                                                                    "id": [
                                                                                        "eq": addr
                                                                                    ]
                                                                                 ].toAnyValue(),
                                                                                 result: "boc",
                                                                                 timeout: nil)

            try client.net.wait_for_collection(paramsOfWaitForCollection) { response in
                if let error = response.error {
                    fatalError( error.localizedDescription )
                }
                if response.finished {
                    var params: AnyValue!
                    do {
                        params = try paramsJsonToDictionary(paramsJSON).toAnyValue()
                    } catch {
                        fatalError( error.localizedDescription )
                    }
                    if let anyResult = response.result?.result.toAny() as? [String: Any] {
                        guard let boc: String = anyResult["boc"] as? String
                        else { fatalError("Receive result, but Boc not found") }

                        let abi: AnyValue = readAbi(abiPath)
                        let paramsOfEncodeMessage: TSDKParamsOfEncodeMessage = .init(
                            abi: .init(type: .Serialized, value: abi),
                            address: addr,
                            deploy_set: nil,
                            call_set: .init(
                                function_name: method,
                                header: nil,
                                input: params
                            ),
                            signer: .init(type: .None),
                            processing_try_index: nil
                        )

                        try client.abi.encode_message(paramsOfEncodeMessage) { response in
                            if let error = response.error {
                                fatalError( error.localizedDescription )
                            }
                            if response.finished {
                                let message: String = response.result!.message
                                let paramsOfRunTvm: TSDKParamsOfRunTvm = .init(message: message,
                                                                               account: boc,
                                                                               execution_options: nil,
                                                                               abi: TSDKAbi(type: .Serialized, value: abi),
                                                                               boc_cache: nil,
                                                                               return_updated_account: nil)


                                try client.tvm.run_tvm(paramsOfRunTvm) { response in
                                    if let error = response.error {
                                        fatalError( error.localizedDescription )
                                    }
                                    if response.finished {
                                        let tvmResult: TSDKResultOfRunTvm = response.result!
                                        guard let output: String = tvmResult.decoded?.output?.toJSON()
                                        else { fatalError( "output not defined" ) }
                                        functionResult = output
                                        group.leave()
                                    }
                                }
                            }
                        }
                    } else {
                        fatalError( "Boc not found" )
                    }
                }
            }
            group.wait()

            let stdout: FileHandle = FileHandle.standardOutput
            stdout.write(functionResult.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) ?? Data())
            return functionResult
        }

        @discardableResult
        func makeResultWithBoc() throws -> String {
            try setClient(options: options)
            var functionResult: String = ""
            let group: DispatchGroup = .init()
            group.enter()

            var params: AnyValue!
            do {
                params = try paramsJsonToDictionary(paramsJSON).toAnyValue()
            } catch {
                fatalError( error.localizedDescription )
            }


            let abi: AnyValue = readAbi(abiPath)
            let paramsOfEncodeMessage: TSDKParamsOfEncodeMessage = .init(
                abi: .init(type: .Serialized, value: abi),
                address: addr,
                deploy_set: nil,
                call_set: .init(
                    function_name: method,
                    header: nil,
                    input: params
                ),
                signer: .init(type: .None),
                processing_try_index: nil
            )

            try client.abi.encode_message(paramsOfEncodeMessage) { response in
                if let error = response.error {
                    fatalError( error.localizedDescription )
                }
                if response.finished {
                    let message: String = response.result!.message
                    let paramsOfRunTvm: TSDKParamsOfRunTvm = .init(message: message,
                                                                   account: boc,
                                                                   execution_options: nil,
                                                                   abi: TSDKAbi(type: .Serialized, value: abi),
                                                                   boc_cache: nil,
                                                                   return_updated_account: nil)
                    try client.tvm.run_tvm(paramsOfRunTvm) { response in
                        if let error = response.error {
                            fatalError( error.localizedDescription )
                        }
                        if response.finished {
                            let tvmResult: TSDKResultOfRunTvm = response.result!
                            guard let output: String = tvmResult.decoded?.output?.toJSON()
                            else { fatalError( "output not defined" ) }
                            functionResult = output
                            group.leave()
                        }
                    }
                }
            }
            group.wait()

            let stdout: FileHandle = FileHandle.standardOutput
            stdout.write(functionResult.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) ?? Data())
            return functionResult
        }
    }
}
