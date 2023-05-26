// The Swift Programming Language
import Foundation
import adnl_swift
//import Crypto
//import CryptoKit
//import CNIOBoringSSL
import CryptoSwift
import SwiftExtensionsPack
import Network
import Vapor
import Dispatch
import Logging

let ADNL_PUB_KEY = "BYSVpL7aPk0kU5CtlsIae/8mf2B/NrBi7DKmepcjX6Q="
var p: ADNLKeys!
var par: ADNLAESParams!
var addr: ADNLAddress!
var cipher: AESADNL!
var decipher: AESADNL!

var handshake: Data!


@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let evetnLoop: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let app: Application = .init(env, Application.EventLoopGroupProvider.shared(evetnLoop))

        defer { app.shutdown() }
        try await configure(app)
        Thread { do { try Client().run() } catch {} }.start()
        try await app.runFromAsyncMainEntrypoint()
        
//        try Client().run()
//        try run()
    }
}

/// This extension is temporary and can be removed once Vapor gets this support.
private extension Vapor.Application {
    static let baseExecutionQueue = DispatchQueue(label: "vapor.codes.entrypoint")
    
    func runFromAsyncMainEntrypoint() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Vapor.Application.baseExecutionQueue.async { [self] in
                do {
                    try self.run()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
