//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 18.05.2023.
//

import Foundation
import NIOCore
import NIOPosix
import SwiftExtensionsPack
import adnl_swift

struct Client {

    func run() throws {
        let ADNL_PUB_KEY = "BYSVpL7aPk0kU5CtlsIae/8mf2B/NrBi7DKmepcjX6Q="
        p = try ADNLKeys(peerPublicKey: ADNL_PUB_KEY)
        par = ADNLAESParams()
        addr = try ADNLAddress(publicKey: ADNL_PUB_KEY)
        handshake = try AESADNL.adnlHandshake(keys: p, params: par, address: addr)
        pe(p.public.toHexadecimal)
        try pe(AESADNL.adnlParseHandshake(handshake).senderPubKey.toHexadecimal)
        cipher = try AESADNL(key: par.txKey, iv: par.txNonce, mode: .encryptor)
        decipher = try AESADNL(key: par.rxKey, iv: par.rxNonce, mode: .decryptor)
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let bootstrap = ClientBootstrap(group: group)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(EchoHandler())
            }
//        let channel = try bootstrap.connect(unixDomainSocketPath: "/tmp/nio.launchd.sock").wait()
        let addr: SocketAddress = try .init(ipAddress: "65.21.141.231", port: 17728)
//        let addr: SocketAddress = try .init(ipAddress: "127.0.0.1", port: 4455)
        let channel = try bootstrap.connect(to: addr).wait()
        try channel.closeFuture.wait()
    }
}



var start: Bool = true

private final class EchoHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    private var numBytes = 0

    public func channelActive(context: ChannelHandlerContext) {
        print("Client connected to \(context.remoteAddress!)")
        // We are connected. It's time to send the message to the server to initialize the ping-pong sequence.
//        let buffer = context.channel.allocator.buffer(string: "hello")
        let buffer = context.channel.allocator.buffer(bytes: handshake)
        pe(handshake.toHexadecimal)
//        self.numBytes = buffer.readableBytes
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        pe("-------------------------------------------------------------")
        pe("-------------------------------------------------------------")
//        let dat = "299d6f35c033dfac4f64b09576e5f4afa73f17fa807b39870b3407b0a0206bac6180e211f871120d1029e6c3b3b6796f15be99072a2019a860acee39fc50ae9c89bdd4e275defc5645035b12939d05c07a077ae6c8fa3644d6298930a71fec07e4470361c7fa8b9e4b5f9fddc104d1773a5fda43".dataFromHex!
//        var decr = try! decipher.decrypt(dat)
//        pe("decr_0", decr.toHexadecimal)
//
//        decr = try! decipher.decrypt(dat)
//        pe("decr_1", decr.toHexadecimal)
//
//        decr = try! decipher.decrypt(dat)
//        pe("decr_2", decr.toHexadecimal)
//
//        decr = try! decipher.decrypt(dat)
//        pe("decr_3", decr.toHexadecimal)
//
//        decr = try! decipher.decrypt(dat)
//        pe("decr_4", decr.toHexadecimal)
        
//        var decr_0 = try! decipher2.update(withBytes: dat.bytes, isLast: false)
//        pe("decr_0-0", Data(decr_0).toHexadecimal)
//
//        decr_0 = try! decipher2.update(withBytes: dat.bytes, isLast: false)
//        pe("decr_0-1", Data(decr_0).toHexadecimal)
        
        
        if !start {
            var byteBuffer = self.unwrapInboundIn(data)
            let data = Data(byteBuffer.readBytes(length: byteBuffer.readableBytes)!)
            var decr = try! decipher.adnlDeserializeMessage(data: data)
            decr = decr[decr.count - 7..<decr.count - 3]
            let unix: UInt32 = .init([UInt8](decr), endian: .littleEndian)
            pe(Date(timeIntervalSince1970: TimeInterval(unix)))
        }
        
        if start {
            pe("START")
            var byteBuffer = self.unwrapInboundIn(data)
            
            print("byteBuffer.readableBytes", byteBuffer.readableBytes)
            print("byteBuffer.writableBytes", byteBuffer.writableBytes)
//            let string = String(buffer: byteBuffer)
            let data = Data(byteBuffer.readBytes(length: byteBuffer.readableBytes)!)
            let kulek = try! decipher.adnlDeserializeMessage(data: data)
            pe("---", kulek.count)
            if kulek.count == 0 {
                pe("TL_GETTIME")
                start = false
                let TL_GETTIME = "7af98bb435263e6c95d6fecb497dfd0aa5f031e7d412986b5ce720496db512052e8f2d100cdf068c7904345aad16000000000000"
//                let paket = ADNLPacket(payload: TL_GETTIME.dataFromHex!)
                let data = try! cipher.adnlSerializeMessage(data: TL_GETTIME.dataFromHex!)
//                pe("request", data.toHexadecimal)
                let buffer = context.channel.allocator.buffer(bytes: data)
                context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
            }
        }
        
        
        
        
//        print("byteBuffer.readableBytes", data.toHexadecimal)
//        print("Received: '\(string)'")
        
//        print(self.numBytes)
//        self.numBytes -= byteBuffer.readableBytes
//        print(self.numBytes)

//        if self.numBytes == 0 {
//            let string = String(buffer: byteBuffer)
//            print("Received: '\(string)' back from the server, closing channel.")
//            context.close(promise: nil)
//        }
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}
