//
//  PaymentURIInterface.swift
//  Zashi
//
//  Created on 2026-03-19.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    public var paymentURI: PaymentURIClient {
        get { self[PaymentURIClient.self] }
        set { self[PaymentURIClient.self] = newValue }
    }
}

/// Client for Payment URI operations.
///
/// Uses the `key` from the Payment URI as a seed for standard ZIP-32 derivation.
/// All crypto is handled by the existing SDK — no custom FFI needed.
@DependencyClient
public struct PaymentURIClient {
    /// Parses a Payment URI string into its components.
    public var parse: (String) -> PaymentURI? = { _ in nil }

    /// Encodes a PaymentURI into its string representation.
    public var encode: (PaymentURI) -> String = { _ in "" }
}
