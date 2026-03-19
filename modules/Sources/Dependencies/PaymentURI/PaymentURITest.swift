//
//  PaymentURITest.swift
//  Zashi
//
//  Created on 2026-03-19.
//

import ComposableArchitecture

extension PaymentURIClient: TestDependencyKey {
    public static let testValue = Self(
        parse: unimplemented("\(Self.self).parse", placeholder: nil),
        encode: unimplemented("\(Self.self).encode", placeholder: "")
    )
}
