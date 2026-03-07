//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SharedBusinessCardsScreen: View {
    @Environment(AppState.self) private var appState

    @State private var cards: [SharedBusinessCard] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    @State private var currentPage = 1
    @State private var errorMessage: String?
    @State private var isCheckingBusinessCard = false
    @State private var activeSheetMode: SharedBusinessCardSheetMode?
    @State private var pendingToggleIDs: Set<String> = []

    private let pageSize = 20

    var body: some View {
        List {
            if isLoading && cards.isEmpty {
                HStack {
                    Spacer(minLength: 0)
                    ProgressView()
                        .tint(.primary)
                    Spacer(minLength: 0)
                }
            } else if cards.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.square")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No shared business cards")
                        .font(.headline)
                    Text("Use the plus button to create your first shared business card.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(cards) { card in
                    NavigationLink {
                        SharedBusinessCardDetailScreen(sharedBusinessCardID: card.id)
                    } label: {
                        sharedBusinessCardRow(card)
                    }
                    .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                activeSheetMode = .edit(card)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                Task { await deleteSharedBusinessCard(card) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onAppear {
                            Task {
                                await loadMoreIfNeeded(currentCardID: card.id)
                            }
                        }
                }

                if isLoadingMore {
                    HStack {
                        Spacer(minLength: 0)
                        ProgressView()
                            .tint(.primary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Shared cards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await onShareBusinessCard() }
                } label: {
                    if isCheckingBusinessCard {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .disabled(isCheckingBusinessCard)
                .accessibilityLabel("Share business card")
            }
        }
        .sheet(item: $activeSheetMode) { mode in
            SharedBusinessCardSheet(mode: mode) { draft in
                await submitSharedBusinessCard(mode: mode, draft: draft)
            }
        }
        .onFirstAppear {
            await loadSharedBusinessCards(forceRefresh: true)
        }
        .refreshable {
            await loadSharedBusinessCards(forceRefresh: true)
        }
        .errorAlertToast($errorMessage)
    }

    @ViewBuilder
    private func sharedBusinessCardRow(_ card: SharedBusinessCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(card.titleText)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .lineLimit(2)

                if let note = card.note?.nilIfEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let name = card.thirdPartyName?.nilIfEmpty {
                    Label(name, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let email = card.thirdPartyEmail?.nilIfEmpty {
                    Label(email, systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let createdAt = card.createdAt {
                    Text("Created \(createdAt.shortDateAndTimeLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Enabled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Toggle("", isOn: bindingForEnabled(card))
                .labelsHidden()
                .disabled(pendingToggleIDs.contains(card.id))
            }
        }
        .padding(.vertical, 6)
    }

    private func bindingForEnabled(_ card: SharedBusinessCard) -> Binding<Bool> {
        Binding(
            get: { card.revokedAt == nil },
            set: { newValue in
                Task { await setEnabled(newValue, for: card) }
            }
        )
    }

    @MainActor
    private func onShareBusinessCard() async {
        guard !isCheckingBusinessCard else {
            return
        }

        isCheckingBusinessCard = true
        defer { isCheckingBusinessCard = false }

        do {
            let exists = try await appState.activeBusinessCardExists()
            if !exists {
                errorMessage = "You need to create a business card first."
                return
            }

            activeSheetMode = .create
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadSharedBusinessCards(forceRefresh: Bool) async {
        if !forceRefresh, !cards.isEmpty {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await appState.fetchSharedBusinessCards(page: 1, size: pageSize)
            cards = page.data ?? []
            currentPage = 1
            canLoadMore = (page.data ?? []).count >= pageSize
            errorMessage = nil
        } catch {
            cards = []
            currentPage = 1
            canLoadMore = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadMoreIfNeeded(currentCardID: String) async {
        guard !isLoading, !isLoadingMore, canLoadMore else {
            return
        }

        guard currentCardID == cards.last?.id else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1

        do {
            let page = try await appState.fetchSharedBusinessCards(page: nextPage, size: pageSize)
            let incoming = page.data ?? []
            appendUniqueCards(incoming)
            currentPage = nextPage
            canLoadMore = incoming.count >= pageSize
            errorMessage = nil
        } catch {
            canLoadMore = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func submitSharedBusinessCard(
        mode: SharedBusinessCardSheetMode,
        draft: SharedBusinessCardDraft
    ) async -> Bool {
        do {
            switch mode {
            case .create:
                let created = try await appState.createSharedBusinessCard(
                    title: draft.title,
                    note: draft.note,
                    thirdPartyName: draft.thirdPartyName,
                    thirdPartyEmail: draft.thirdPartyEmail
                )
                cards.insert(created, at: 0)
            case .edit(let card):
                let updated = try await appState.updateSharedBusinessCard(
                    id: card.id,
                    title: draft.title,
                    note: draft.note,
                    thirdPartyName: draft.thirdPartyName,
                    thirdPartyEmail: draft.thirdPartyEmail
                )
                replaceSharedBusinessCard(updated)
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    @MainActor
    private func setEnabled(_ isEnabled: Bool, for card: SharedBusinessCard) async {
        guard pendingToggleIDs.insert(card.id).inserted else {
            return
        }

        defer {
            pendingToggleIDs.remove(card.id)
        }

        do {
            if isEnabled {
                try await appState.unrevokeSharedBusinessCard(id: card.id)
            } else {
                try await appState.revokeSharedBusinessCard(id: card.id)
            }

            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index].revokedAt = isEnabled ? nil : Date()
            }

            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func deleteSharedBusinessCard(_ card: SharedBusinessCard) async {
        do {
            try await appState.deleteSharedBusinessCard(id: card.id)
            cards.removeAll { $0.id == card.id }
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func appendUniqueCards(_ incoming: [SharedBusinessCard]) {
        guard !incoming.isEmpty else {
            return
        }

        let existingIds = Set(cards.map(\.id))
        cards.append(contentsOf: incoming.filter { !existingIds.contains($0.id) })
    }

    private func replaceSharedBusinessCard(_ updated: SharedBusinessCard) {
        if let index = cards.firstIndex(where: { $0.id == updated.id }) {
            cards[index] = updated
        } else {
            cards.insert(updated, at: 0)
        }
    }
}
