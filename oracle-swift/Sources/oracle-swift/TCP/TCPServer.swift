//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 25.05.2023.
//

import Foundation
import NIOCore
import NIOPosix
import launch

class Server {
    static func run() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount * 2)
        let bootstrap = ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        // Set the handlers that are appled to the accepted Channels
            .childChannelInitializer { channel in
                // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                channel.pipeline.addHandler(BackPressureHandler()).flatMap { v in
                    channel.pipeline.addHandler(EchoHandler())
                }
            }
        
        // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        // Bootstrap
        let server = try bootstrap.bind(host: "127.0.0.1", port: 44551).wait()
        try server.closeFuture.wait()
    }
}




private final class EchoHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    public func channelRegistered(context: ChannelHandlerContext) {
        pe("channelRegistered")
        context.fireChannelRegistered()
    }

    public func channelUnregistered(context: ChannelHandlerContext) {
        pe("channelUnregistered")
        context.fireChannelUnregistered()
    }

//    public func channelActive(context: ChannelHandlerContext) {
//        context.fireChannelActive()
//    }

    public func channelInactive(context: ChannelHandlerContext) {
        pe("channelInactive")
        context.fireChannelInactive()
    }

//    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        pe("channelRead")
//        context.fireChannelRead(data)
//    }

//    public func channelReadComplete(context: ChannelHandlerContext) {
//        context.fireChannelReadComplete()
//    }

    public func channelWritabilityChanged(context: ChannelHandlerContext) {
        pe("channelWritabilityChanged")
        context.fireChannelWritabilityChanged()
    }

    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        pe("userInboundEventTriggered")
        context.fireUserInboundEventTriggered(event)
    }

//    public func errorCaught(context: ChannelHandlerContext, error: Error) {
//        context.fireErrorCaught(error)
//    }
    
    public func channelActive(context: ChannelHandlerContext) {
        print("Client connected to \(context.remoteAddress!)")
        arr.append(context)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        pe("channelRead")
//        context.write(data, promise: nil)
//        for c in arr.filter({ $0.remoteAddress!.ipAddress != context.remoteAddress!.ipAddress }) {
//            c.write(data, promise: nil)
//        }
        
        for c in arr {
            c.eventLoop.any().execute {
                c.write(data, promise: nil)
                c.writeAndFlush(data, promise: nil)
            }
        }
//        context.writeAndFlush(data, promise: nil)
    }
    
    // Flush it out. This can make use of gathering writes if multiple buffers are pending
    public func channelReadComplete(context: ChannelHandlerContext) {
        pe("context.flush()")
        context.flush()
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}

var arr: [ChannelHandlerContext] = .init()
