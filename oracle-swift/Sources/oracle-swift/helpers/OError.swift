//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 25.05.2023.
//

import Foundation
import SwiftExtensionsPack

public struct OError: ErrorCommon {
    public var title: String = "OracleCommon"
    public var reason: String = ""
    public init() {}
}
