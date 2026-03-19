//
//  PaymentURIFinalizeView.swift
//  Zashi
//
//  Simple debug view for testing Payment URI finalization.
//

import SwiftUI
import ComposableArchitecture
import PaymentURI

public struct PaymentURIFinalizeView: View {
    let store: StoreOf<PaymentURIFinalize>

    public init(store: StoreOf<PaymentURIFinalize>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 16) {
                Text("Payment URI Finalize")
                    .font(.headline)

                statusView

                if case .idle = store.step {
                    Button("Finalize Payment") {
                        let key: [UInt8] = [
                            0x94, 0x73, 0x4c, 0xaf, 0xa7, 0x30, 0xf9, 0x16,
                            0xf1, 0xd2, 0x89, 0x80, 0xd3, 0x1e, 0x63, 0xb5,
                            0x70, 0x46, 0x53, 0x79, 0x45, 0x99, 0xbd, 0xc0,
                            0x97, 0x21, 0xc2, 0xe1, 0xf1, 0xc2, 0x86, 0x8c
                        ]

                        let uri = PaymentURI(
                            key: key,
                            amount: 300_000,
                            birthdayHeight: 3_278_023
                        )

                        store.send(.finalize(
                            uri,
                            recipientAddress: "u1ax6yajnd9j7l9388kzamatxqcgljugk7l7jkgln9vn0mx7nntl7kk3un9u8z9wre2eeafg7l595e3umnsew43w876mc9asrmhnfxq97hak59vtljl6nhm2eu7t2dp0e4qwcv8h98mnnnuwq60qpu7qxlcyarzft5s9scm0gnjggvs0pf"
                        ))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    var statusView: some View {
        switch store.step {
        case .idle:
            Text("Ready to finalize")
                .foregroundStyle(.secondary)
        case .deriving:
            Label("Deriving keys...", systemImage: "key")
        case .importing:
            Label("Importing account...", systemImage: "person.badge.plus")
        case .syncing(let progress):
            VStack {
                Label("Syncing...", systemImage: "arrow.triangle.2.circlepath")
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
            }
        case .proposing:
            Label("Creating proposal...", systemImage: "doc.text")
        case .sending:
            Label("Signing & broadcasting...", systemImage: "paperplane")
        case .success(let txIds):
            VStack {
                Label("Success!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                ForEach(txIds, id: \.self) { txId in
                    Text(txId)
                        .font(.caption2)
                        .monospaced()
                }
            }
        case .failed(let message):
            VStack {
                Label("Failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
