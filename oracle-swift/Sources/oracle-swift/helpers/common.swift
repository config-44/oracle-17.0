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
    case info
    case notice
}

public func errorPrint(_ error: Error, _ mode: ErrorPrint = .warning, _ line: Int = #line, _ function: String = #function) {
    switch mode {
    case .warning:
        logger.warning("\(makeError(OError(String(describing: error)), function, line).localizedDescription)")
    case .critical:
        logger.critical("\(makeError(OError(String(describing: error)), function, line).localizedDescription)")
    case .info:
        logger.info("\(makeError(OError(String(describing: error)), function, line).localizedDescription)")
    case .notice:
        logger.notice("\(makeError(OError(String(describing: error)), function, line).localizedDescription)")
    }
}

let ep = errorPrint
let log = errorPrint
public func logg(_ error: Error, _ mode: ErrorPrint = .warning, _ line: Int = #line, _ function: String = #function) {
    errorPrint(error, mode, line, function)
}
public func logg(_ mode: ErrorPrint = .notice, _ line: Int = #line, _ function: String = #function, text: Any...) {
    let content: [Any] = ["asdf"] + text
    let text = content.map{"\($0)"}.join(" ")
    switch mode {
    case .warning:
        logger.warning("\(text)")
    case .critical:
        logger.critical("\(text)")
    case .info:
        logger.info("\(text)")
    case .notice:
        logger.notice("\(text)")
    }
}

public func errorPrint(_ str: String) {
    logger.info("\(str)")
}
