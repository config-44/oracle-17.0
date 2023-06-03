//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 31.05.2023.
//

import Foundation
import EverscaleClientSwift
import BigInt
import SwiftExtensionsPack

public final class TvmCellBuilder {
    
    private var ops: [TSDKBuilderOp] = .init()
    
    func build() -> [TSDKBuilderOp] {
        ops
    }
    
    @discardableResult
    func storeUInt(value: BigInt, size: UInt32) -> Self {
        ops.append(
            .init(
                type: .Integer,
                size: size,
                value: .string(String(value))
            )
        )
        return self
    }
    
    @discardableResult
    func storeBytes(value: String) -> Self {
        ops.append(
            .init(
                type: .BitString,
                value: .string(value)
            )
        )
        return self
    }
    
    @discardableResult
    func storeBit(value: Bit) -> Self {
        storeUInt(value: value.rawValue == 1 ? 1 : 0, size: 1)
        return self
    }
    
    @discardableResult
    func storeBits(bits: [Bit]) -> Self {
        bits.forEach { storeBit(value: $0) }
        return self
    }
    
    @discardableResult
    func storeCellRefFromBoc(value: String) -> Self {
        ops.append(
            .init(
                type: .CellBoc,
                boc: value
            )
        )
        return self
    }
    
    @discardableResult
    func storeCellRef(builder: [TSDKBuilderOp]) -> Self {
        ops.append(
            .init(
                type: .Cell,
                builder: builder
            )
        )
        return self
    }
    
    /// var_uint$_ {n:#} len:(#< n) value:(uint (len * 8)) = VarUInteger n;
    @discardableResult
    func storeVarUInt(value: BigInt, len: Int) throws -> Self {
        let size: UInt32 = UInt32(log2(Double(len)).round(toDecimalPlaces: 0, rule: .up))
        if value == 0 {
            storeUInt(value: 0, size: size)
        } else {
            let arr: [BigInt] = (0...BigInt(len)).map { $0 * 8 }
            guard let bitLen: BigInt = arr.filter({ value < (1 << $0) }).first else {
                throw makeError(TSDKClientError("No value"))
            }
            storeUInt(value: BigInt((Double(bitLen) / 8).round(toDecimalPlaces: 0, rule: .up)), size: size)
            storeUInt(value: value, size: UInt32(bitLen))
        }
        return self
    }
    
    /// nanograms$_ amount:(VarUInteger 16) = Grams;
    @discardableResult
    func storeGrams(value: BigInt) throws -> Self {
        try storeVarUInt(value: value, len: 16)
    }
    
    @discardableResult
    func storeAddress(address: String) -> Self {
        if address.isEmpty {
            storeBits(bits: [.b0, .b0])
        } else {
            ops.append(
                .init(
                    type: .Address,
                    address: address
                )
            )
        }
        
        return self
    }
    
    @discardableResult
    func append(builder: TvmCellBuilder) -> Self {
        ops += builder.build()
        return self
    }
    
    @discardableResult
    func append(options: [TSDKBuilderOp]) -> Self {
        ops += options
        return self
    }
    
    public enum Bit: UInt32 {
        case b0
        case b1
    }
}
