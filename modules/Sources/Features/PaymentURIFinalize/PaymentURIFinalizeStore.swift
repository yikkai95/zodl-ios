//
//  PaymentURIFinalizeStore.swift
//  Zashi
//
//  Payment URI finalization (step 5): scan QR → import ephemeral account → sweep to own address.
//

import ComposableArchitecture
import DerivationTool
import Models
import PaymentURI
import SDKSynchronizer
import ZcashLightClientKit
import ZcashSDKEnvironment

@Reducer
public struct PaymentURIFinalize {
    @ObservableState
    public struct State: Equatable {
        public enum Step: Equatable {
            case idle
            case deriving
            case importing
            case syncing(progress: Float)
            case proposing
            case sending
            case success(txIds: [String])
            case failed(message: String)
        }

        /// The parsed Payment URI (key + amount + birthdayHeight).
        public var uri: PaymentURI?
        /// The recipient's own unified address to sweep funds to.
        public var recipientAddress: String
        /// Current step in the finalization process.
        public var step: Step = .idle
        /// The imported ephemeral account UUID.
        public var ephemeralAccountUUID: AccountUUID?

        public init(recipientAddress: String = "") {
            self.recipientAddress = recipientAddress
        }
    }

    public enum Action: Equatable {
        case finalize(PaymentURI, recipientAddress: String)
        case derivedKeys(UnifiedSpendingKey, String)
        case accountImported(AccountUUID, UnifiedSpendingKey)
        case syncProgressUpdated(Float)
        case syncComplete(AccountUUID, UnifiedSpendingKey)
        case proposalReady(Proposal, UnifiedSpendingKey)
        case transactionResult(SDKSynchronizerClient.CreateProposedTransactionsResult)
        case failed(String)
    }

    @Dependency(\.derivationTool) var derivationTool
    @Dependency(\.sdkSynchronizer) var sdkSynchronizer
    @Dependency(\.zcashSDKEnvironment) var zcashSDKEnvironment

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .finalize(uri, recipientAddress):
                state.uri = uri
                state.recipientAddress = recipientAddress
                state.step = .deriving
                return .run { send in
                    do {
                        let network = zcashSDKEnvironment.network.networkType

                        // 1. Derive spending key and UFVK from Payment URI key (key = seed)
                        let usk = try derivationTool.deriveSpendingKey(
                            uri.key,
                            Zip32AccountIndex(0),
                            network
                        )
                        let ufvk = try derivationTool.deriveUnifiedFullViewingKey(usk, network)
                        let ufvkString = ufvk.stringEncoded

                        await send(.derivedKeys(usk, ufvkString))
                    } catch {
                        await send(.failed("Key derivation failed: \(error.localizedDescription)"))
                    }
                }

            case let .derivedKeys(usk, ufvkString):
                state.step = .importing
                return .run { send in
                    do {
                        // 2. Import ephemeral account
                        let uuid = try await sdkSynchronizer.importAccount(
                            ufvkString,
                            nil,                        // no seed fingerprint
                            Zip32AccountIndex(0),
                            AccountPurpose.spending,
                            "Payment URI",
                            "payment-uri"
                        )

                        guard let uuid else {
                            await send(.failed("Failed to import ephemeral account"))
                            return
                        }

                        await send(.accountImported(uuid, usk))
                    } catch {
                        await send(.failed("Account import failed: \(error.localizedDescription)"))
                    }
                }

            case let .accountImported(uuid, usk):
                state.ephemeralAccountUUID = uuid
                state.step = .syncing(progress: 0)
                return .run { send in
                    // 3. Wait for sync to find the note
                    // Listen to sync state stream until we see a balance
                    for await syncState in sdkSynchronizer.stateStream().values {
                        let progress = syncState.syncStatus.progress
                        await send(.syncProgressUpdated(Float(progress)))

                        if case .upToDate = syncState.syncStatus {
                            await send(.syncComplete(uuid, usk))
                            return
                        }
                    }
                }

            case let .syncProgressUpdated(progress):
                state.step = .syncing(progress: progress)
                return .none

            case let .syncComplete(uuid, usk):
                state.step = .proposing
                let recipientAddress = state.recipientAddress
                guard let uri = state.uri else {
                    return .send(.failed("No Payment URI"))
                }
                return .run { send in
                    do {
                        // 4. Propose transfer from ephemeral account to recipient
                        let recipient = try Recipient(
                            recipientAddress,
                            network: zcashSDKEnvironment.network.networkType
                        )

                        let proposal = try await sdkSynchronizer.proposeTransfer(
                            uuid,
                            recipient,
                            Zatoshi(Int64(uri.amount)),
                            nil
                        )

                        await send(.proposalReady(proposal, usk))
                    } catch {
                        await send(.failed("Proposal failed: \(error.localizedDescription)"))
                    }
                }

            case let .proposalReady(proposal, usk):
                state.step = .sending
                return .run { send in
                    do {
                        // 5. Sign and broadcast
                        let result = try await sdkSynchronizer.createProposedTransactions(
                            proposal,
                            usk
                        )
                        await send(.transactionResult(result))
                    } catch {
                        await send(.failed("Transaction failed: \(error.localizedDescription)"))
                    }
                }

            case let .transactionResult(result):
                switch result {
                case .success(let txIds):
                    state.step = .success(txIds: txIds)
                case .failure(let txIds, let code, let desc):
                    state.step = .failed("Tx failed (\(code)): \(desc). TxIds: \(txIds)")
                case .grpcFailure(let txIds):
                    state.step = .failed("Network error (resubmittable). TxIds: \(txIds)")
                case .partial(let txIds, let statuses):
                    state.step = .failed("Partial: \(txIds), statuses: \(statuses)")
                }
                return .none

            case let .failed(message):
                state.step = .failed(message: message)
                return .none
            }
        }
    }
}
