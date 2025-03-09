//
//  EquatableError.swift
//  Tribuneros
//
//  Created by albert vila on 3/3/25.
//

import Foundation

struct EquatableError: Error, Equatable, CustomStringConvertible {
    public let base: Error
    private let equals: (Error) -> Bool

    init<Base: Error>(_ base: Base) {
        self.base = base
        self.equals = { String(reflecting: $0) == String(reflecting: base) }
    }

    init<Base: Error & Equatable>(_ base: Base) {
        self.base = base
        self.equals = { ($0 as? Base) == base }
    }

    static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
        lhs.equals(rhs.base)
    }

    var description: String {
        "\(self.base)"
    }

     func asError<Base: Error>(type: Base.Type) -> Base? {
        self.base as? Base
    }
    
    var logDescription: String {
        self.base.localizedDescription
    }
}

extension Error where Self: Equatable {
    func toEquatableError() -> EquatableError {
        EquatableError(self)
    }
}

extension Error {
    func toEquatableError() -> EquatableError {
        EquatableError(self)
    }
}

import Combine

extension Publisher where Failure == Never {
  func weakAssign<O: AnyObject>(
      to keyPath: ReferenceWritableKeyPath<O, Output>,
      on object: O
  ) -> AnyCancellable {
      sink { [weak object] value in
          object?[keyPath: keyPath] = value
      }
  }
}
