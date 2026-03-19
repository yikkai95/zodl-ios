//
//  PaymentURITypes.swift
//  Zashi
//
//  Created on 2026-03-19.
//

import Foundation

/// A parsed Payment URI containing the key and amount for an ephemeral payment.
///
/// The `key` is a 32-byte value used as a seed for standard ZIP-32 key derivation
/// (account index 0). Both sender and recipient derive the same spending key,
/// viewing key, and address from this seed using `DerivationTool.deriveSpendingKey`.
///
/// Flow:
/// 1. Sender generates `key`, derives address via `deriveSpendingKey(key, 0)`
/// 2. Sender sends `amount` to that address
/// 3. Sender shows QR (key + amount + birthdayHeight) to recipient
/// 4. Recipient scans QR, derives same keys, imports account, syncs, sweeps to own wallet
public struct PaymentURI: Equatable {
    /// The 32-byte ephemeral key used as seed for ZIP-32 key derivation.
    public let key: [UInt8]

    /// The amount in zatoshis.
    public let amount: UInt64

    /// Optional human-readable description of the payment.
    public let desc: String?

    /// Block height for wallet sync start.
    public let birthdayHeight: UInt32

    public init(key: [UInt8], amount: UInt64, desc: String? = nil, birthdayHeight: UInt32) {
        self.key = key
        self.amount = amount
        self.desc = desc
        self.birthdayHeight = birthdayHeight
    }
}

// MARK: - URI Encoding/Decoding

public extension PaymentURI {
    /// The URI scheme for ephemeral payment URIs.
    static let scheme = "zcash-payment"

    /// Parses a Payment URI string.
    ///
    /// Format: `zcash-payment:?key=<base64url>&amount=<decimal>&h=<height>[&desc=<text>]`
    static func parse(_ uriString: String) -> PaymentURI? {
        guard let components = URLComponents(string: uriString),
              components.scheme == Self.scheme else {
            return nil
        }

        let queryItems = components.queryItems ?? []

        guard let keyString = queryItems.first(where: { $0.name == "key" })?.value,
              let keyData = base64URLDecode(keyString),
              keyData.count == 32 else {
            return nil
        }

        guard let amountString = queryItems.first(where: { $0.name == "amount" })?.value,
              let amountZec = Double(amountString) else {
            return nil
        }

        guard let heightString = queryItems.first(where: { $0.name == "h" })?.value,
              let height = UInt32(heightString) else {
            return nil
        }

        let desc = queryItems.first(where: { $0.name == "desc" })?.value
        let amountZatoshis = UInt64(amountZec * 100_000_000)

        return PaymentURI(
            key: Array(keyData),
            amount: amountZatoshis,
            desc: desc,
            birthdayHeight: height
        )
    }

    /// Encodes this Payment URI as a string.
    func toURIString() -> String {
        let keyString = Self.base64URLEncode(Data(key))
        let amountZec = Double(amount) / 100_000_000.0

        var components = URLComponents()
        components.scheme = Self.scheme
        components.queryItems = [
            URLQueryItem(name: "key", value: keyString),
            URLQueryItem(name: "amount", value: String(format: "%.8f", amountZec)),
            URLQueryItem(name: "h", value: String(birthdayHeight))
        ]

        if let desc {
            components.queryItems?.append(URLQueryItem(name: "desc", value: desc))
        }

        return components.string ?? ""
    }

    // MARK: - Base64URL helpers

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
