//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 15.05.2023.
//

import Foundation
import SwiftExtensionsPack
import Vapor

/// asdf print
public func pe(_ line: Any...) {
    #if DEBUG
    let content: [Any] = ["asdf"] + line
    print(content.map{"\($0)"}.join(" "))
    #endif
}


public enum ErrorPrint {
    case warning
    case critical
}

public func errorPrint(_ app: Application, _ error: Error, _ mode: ErrorPrint = .warning) {
    switch mode {
    case .warning:
        app.logger.warning("\(makeError(OError(String(describing: error))).localizedDescription)")
    case .critical:
        app.logger.critical("\(makeError(OError(String(describing: error))).localizedDescription)")
    }
}
