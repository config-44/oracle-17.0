//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 31.05.2023.
//

import Foundation
import EverscaleClientSwift
import SwiftExtensionsPack
import BigInt

extension TSDKClientError: ErrorCommonMessage {}

extension OracleCtrl {
    
    static func runGetMethodFromBoc(boc: String,
                             method: String,
                             params: [Any]? = nil
    ) async throws -> TSDKResultOfRunGet {
        let paramsOfRunGet: TSDKParamsOfRunGet = .init(account: boc,
                                                       function_name: method,
                                                       input: (params ?? []).toAnyValue(),
                                                       execution_options: nil,
                                                       tuple_list_as_array: nil)
        
        return try await Self.client.tvm.run_get(paramsOfRunGet)
    }
    
    static func pwv_getAddress(pubKey: String,
                        wc: Int
    ) async throws -> String {
        let result: TSDKResultOfRunGet = try await runGetMethodFromBoc(boc: PWV2_DEBOT_BOC,
                                                                       method: "address_by_public_key",
                                                                       params: [
                                                                        pubKey.add0x
                                                                       ])
        guard let addr =  (result.output.toAny() as? [String])?[0] else {
            throw makeError(TSDKClientError("Address not found"))
        }
        return "\(wc):\(addr.remove0x)"
    }
}


public extension String {

    var toNanoCrystals: BigInt {
        toNanoCrystals(decimals: 9)
    }
    
    var isValidAmount: Bool {
        self[(#"(^\d+$|(^\d+\.\d+$))"#)]
    }

    func toNanoCrystals(decimals: Int) -> BigInt {
        let balance: String = self.replace(#","#, ".")

        var result: String = ""
        let match: [Int: String] = balance.regexp(#"(\d+)\.(\d+)"#)
        let isFloat: Bool = match[2] != nil
        if isFloat {
            if
                let integer: String = match[1],
                let float: String = match[2]?.replace(#"0+$"#, "")
            {
                var temp: String = ""
                var counter = decimals
                for char in float {
                    if counter == 0 {
                        temp.append(".")
                    }
                    counter -= 1
                    temp.append(char)
                }
                if counter < 0 { return 0 }
                if counter > 0 {
                    for _ in 0..<counter {
                        temp.append("0")
                    }
                }
                if let int = BigInt(integer), int > 0 {
                    temp = "\(integer)\(temp)"
                }
                result = temp
            }
        } else {
            result.append(balance.replace(#"^0+"#, ""))
            for _ in 0..<decimals {
                result.append("0")
            }
        }

        guard let bigInt = BigInt(result) else { fatalError("toNanoCrystals: Not convert \(self) to BigInt") }
        return bigInt
    }

    func nanoCrystalToCrystal(decimals: Int = 9) -> String {
        guard let bigInt = BigInt(self) else { fatalError("toNanoCrystals: Not convert \(self) to BigInt") }
        return bigInt.nanoCrystalToCrystal(decimals: decimals)
    }

    func crystalToNanoCrystal(decimals: Int = 9) -> String {
        String(self.toNanoCrystals(decimals: decimals))
    }
    
    func crystalToNanoCrystal(decimals: Int = 9) -> BigInt {
        self.toNanoCrystals(decimals: decimals)
    }
    
    func shift(_ by: Int) -> String {
        by >= 0 ? crystalToNanoCrystal(decimals: by) : nanoCrystalToCrystal(decimals: by * -1)
    }
    
    func convertDecimals(from: Int, to: Int) -> String {
        self.shift(to - from).roundCut(0)
    }
    
    func roundCut(_ digits: Int = 2) -> String {
        var price = self
        let matches = price.regexp(#"(\d+(,|\.)\d{"# + "\(digits)" + #"})\d*"#)
        if let newPrice = matches[1] {
            price = newPrice
        }
        
        return price.replace(#"\.$"#, "")
    }
    
    func split(_ separator: String) -> [String] {
        if !separator.isEmpty {
            return self.components(separatedBy: separator)
        }
        return self.map { String($0) }
    }
}

extension BigInt {

    var nanoCrystalToCrystal: String {
        nanoCrystalToCrystal(decimals: 9)
    }

    func nanoCrystalToCrystal(decimals: Int) -> String {
        let balanceCount = String(self).count
        let different = balanceCount - decimals
        var floatString = ""
        if different <= 0 {
            floatString = "0."
            for _ in 0..<different * -1 {
                floatString.append("0")
            }
            floatString.append(String(self))
        } else {
            var counter = different
            for char in String(self) {
                if counter == 0 {
                    floatString.append(".")
                }
                floatString.append(char)
                counter -= 1
            }
        }

        return floatString.replace(#"(\.|)0+$"#, "")
    }

    func nanoCrystalsToDouble(decimals: Int = 9) -> Double? {
        let crystalValue = nanoCrystalToCrystal(decimals: decimals)
        return Double(crystalValue)
    }
    
    mutating func up(_ percent: BigInt) {
        self = self + (self * percent) / 100
    }
    
    func up(_ percent: BigInt) -> BigInt {
        self + (self * percent) / 100
    }
}
