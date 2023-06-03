//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 20.09.2021.
//

import Foundation
import ArgumentParser
import EverscaleClientSwift
import FileUtils

extension OracleCtrl {
    struct Env: ParsableCommand, ValidatorToolOptionsPrtcl {
        @OptionGroup var options: ValidatorToolOptions

        public func run() throws {
            try makeResult()
        }

        @discardableResult
        func makeResult() throws -> String {
            if let configPath: String = ProcessInfo.processInfo.environment[envVariableName] ?? ProcessInfo.processInfo.environment[envTonosVariableName]
            {
                let configJSON: String = try FileUtils.readFile(URL(fileURLWithPath: configPath))
                guard let data: Data = configJSON.data(using: .utf8)
                else { fatalError("Bad json. Please check \(configPath) json file with configuration.") }
                guard let json: [String : Any] = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                else { fatalError("Bad json. Please check \(configPath) json file with configuration.") }
                print("\(json)")

                return "\(json)"
            } else {
                fatalError("Please set \(envVariableName) or \(envTonosVariableName) env variable with full path to config.json to your .profile etc")
            }
        }
    }
}
