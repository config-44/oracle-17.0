//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 04.06.2023.
//

import Foundation

@propertyWrapper
struct Atomic<Value> {

    private var value: Value
    private let lock = NSLock()

    init(wrappedValue value: Value) {
        self.value = value
    }

    var wrappedValue: Value {
      get {
          lock.lock()
          defer { lock.unlock() }
          return value
      }
      set {
          lock.lock()
          defer { lock.unlock() }
          value = newValue
      }
    }
}

