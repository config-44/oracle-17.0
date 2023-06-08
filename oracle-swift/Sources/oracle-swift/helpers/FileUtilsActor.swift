//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 07.06.2023.
//

import Foundation
import SwiftExtensionsPack
import FileUtils

actor FileUtilsActor {
    
    func writeToFile(to path: String?,
                     _ text: String?,
                     _ encoding: String.Encoding = .utf8,
                     _ mode: FileUtils.Mode = [.clear]
    ) {
        FileUtils.writeFile(to: path, text, encoding, mode)
    }
}
