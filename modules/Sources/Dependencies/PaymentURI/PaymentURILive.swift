//
//  PaymentURILive.swift
//  Zashi
//
//  Created on 2026-03-19.
//

import ComposableArchitecture

extension PaymentURIClient: DependencyKey {
    public static let liveValue = Self(
        parse: { uriString in
            PaymentURI.parse(uriString)
        },
        encode: { uri in
            uri.toURIString()
        }
    )
}
