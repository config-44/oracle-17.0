// The Swift Programming Language
import Foundation
import SwiftExtensionsPack
import Vapor

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let evetnLoop: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let app: Application = .init(env, Application.EventLoopGroupProvider.shared(evetnLoop))
        defer { app.shutdown() }
        try await configure(app)
        /// TCP
//        TCPConnectionCenter.initialize(serverIp: SERVER_IP, serverPort: SERVER_PORT, serverSecret: SECRET_KEY, peers: [])
//        try TCPConnectionCenter.shared.run()
        
        /// WSS
        Task.detached { try await OracleWSSService.shared.start() }
        
        try await app.runFromAsyncMainEntrypoint()
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
