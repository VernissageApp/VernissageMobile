//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SharedBusinessCardDetailScreen: View {
    @Environment(AppState.self) private var appState

    let sharedBusinessCardID: String

    @State private var card: SharedBusinessCard?
    @State private var isLoading = false
    @State private var isSending = false
    @State private var message = ""
    @State private var errorMessage: String?
    @State private var isShowingQRCode = false

    private var messages: [SharedBusinessCardMessage] {
        card?.messages ?? []
    }

    private var canSend: Bool {
        !isSending && card != nil && message.nilIfEmpty != nil
    }

    private var cardPublicURL: String? {
        guard let code = card?.code?.nilIfEmpty,
              let baseURL = appState.activeAccount?.instanceURL.nilIfEmpty else {
            return nil
        }

        let normalizedBaseURL = baseURL.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        return "\(normalizedBaseURL)/cards/\(code)?update=true"
    }

    private var cardClientDisplayName: String {
        card?.thirdPartyName?.nilIfEmpty ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if isLoading && card == nil {
                        HStack {
                            Spacer(minLength: 0)
                            ProgressView()
                                .tint(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 20)
                    } else if let card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.titleText)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)

                            if let note = card.note?.nilIfEmpty {
                                Text(note)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let createdAt = card.createdAt {
                                Text(createdAt.shortDateAndTimeLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "person.crop.square.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cardClientDisplayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if let email = card.thirdPartyEmail?.nilIfEmpty {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 12)

                            Button {
                                isShowingQRCode = true
                            } label: {
                                Image(systemName: "qrcode")
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.bordered)
                            .disabled(cardPublicURL?.nilIfEmpty == nil)
                        }
                        .padding(.vertical, 6)

                        Divider()

                        if messages.isEmpty {
                            ContentUnavailableView("No messages yet",
                                                   systemImage: "bubble.left.and.bubble.right",
                                                   description: Text("Start the conversation below."))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(messages.indices, id: \.self) { index in
                                    let message = messages[index]
                                    messageRow(message)
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView("Cannot load shared card",
                                               systemImage: "person.crop.square",
                                               description: Text("Try again in a moment."))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 20)
            }

            if card != nil {
                sendMessageField
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Shared card")
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await loadCard()
        }
        .refreshable {
            await loadCard()
        }
        .sheet(isPresented: $isShowingQRCode) {
            if let cardPublicURL = cardPublicURL?.nilIfEmpty {
                SharedBusinessCardQRCodeSheet(urlString: cardPublicURL)
            }
        }
        .errorAlertToast($errorMessage)
    }

    @ViewBuilder
    private func messageRow(_ message: SharedBusinessCardMessage) -> some View {
        if message.addedByUser == true {
            HStack {
                Spacer(minLength: 0)
                Text(message.message?.nilIfEmpty ?? "")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.blue.opacity(0.26))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Text(cardClientDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(message.message?.nilIfEmpty ?? "")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.secondary.opacity(0.22))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sendMessageField: some View {
        HStack(spacing: 10) {
            TextField("Send message...", text: $message, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Button {
                Task { await sendMessage() }
            } label: {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 60)
                } else {
                    Text("Send")
                        .fontWeight(.semibold)
                        .frame(width: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSend)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
        )
    }

    @MainActor
    private func loadCard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            card = try await appState.api.businessCards.fetchSharedBusinessCard(id: sharedBusinessCardID)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage() async {
        guard let trimmedMessage = message.nilIfEmpty else {
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            try await appState.api.businessCards.sendSharedBusinessCardMessage(id: sharedBusinessCardID, message: trimmedMessage)

            if var card {
                var cardMessages = card.messages ?? []
                cardMessages.append(
                    SharedBusinessCardMessage(
                        id: UUID().uuidString,
                        message: trimmedMessage,
                        addedByUser: true,
                        createdAt: Date()
                    )
                )
                card.messages = cardMessages
                self.card = card
            }

            message = ""
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
