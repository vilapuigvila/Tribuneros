//
//  CXRaces.PageLoad.swift
//  Tribuneros
//

import Foundation

extension CXRaces {
    /// The load state of one on-demand CX page (full results, a rider's results, a ranking).
    enum PageLoad<Value: Equatable>: Equatable {
        case idle
        case loading
        case loaded(Value)
        case failed

        var value: Value? {
            guard case .loaded(let value) = self else { return nil }
            return value
        }

        /// Not started, or failed and worth trying again.
        var needsLoad: Bool {
            switch self {
            case .idle, .failed: true
            case .loading, .loaded: false
            }
        }
    }
}
