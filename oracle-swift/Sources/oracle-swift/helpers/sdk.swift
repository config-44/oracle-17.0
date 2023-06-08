//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 08.06.2023.
//

import Foundation
import EverscaleClientSwift
import SwiftExtensionsPack

public func signCellBuilder(_ client: TSDKClientModule, _ cellBuilder: TvmCellBuilder, _ secret: Data) async throws -> String {
    let publicKey: String = try await client.crypto.nacl_sign_keypair_from_secret_key(TSDKParamsOfNaclSignKeyPairFromSecret(secret: secret.toHexadecimal)).public
    let boc: TSDKResultOfEncodeBoc = try await client.boc.encode_boc(TSDKParamsOfEncodeBoc(builder: cellBuilder.build()))
    let hash: String = try await client.boc.get_boc_hash(TSDKParamsOfGetBocHash(boc: boc.boc)).hash
    guard let base64 = hash.dataFromHex?.base64EncodedString() else { throw TSDKClientError("Bad hash \(hash)") }
    let signedBoc: TSDKResultOfSign = try await client.crypto.sign(TSDKParamsOfSign(unsigned: base64,
                                                                                    keys: TSDKKeyPair(public: publicKey,
                                                                                                      secret: secret.toHexadecimal)))
    return signedBoc.signature
}
