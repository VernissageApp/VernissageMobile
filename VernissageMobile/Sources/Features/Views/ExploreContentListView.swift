//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ExploreContentListView: View {
    @Environment(AppState.self) private var appState
    @Binding private var query: String
    @FocusState private var isSearchFieldFocused: Bool

    let selection: ExploreContentSelection
    let viewModel: ExploreViewModel

    init(
        selection: ExploreContentSelection,
        query: Binding<String>,
        viewModel: ExploreViewModel
    ) {
        self.selection = selection
        _query = query
        self.viewModel = viewModel
    }

    var body: some View {
        let items = viewModel.items(for: selection)

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(selection.searchPrompt, text: $query)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit(search)
                .onChange(of: query, initial: false) { oldValue, newValue in
                    handleQueryChange(from: oldValue, to: newValue)
                }

            if !query.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill", action: clearSearch)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .buttonStyle(.plain)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, query.isEmpty ? 14 : 0)
        .frame(minHeight: 44)
        .background(.fill.tertiary, in: .capsule)
        .padding(.horizontal, 16)

        if viewModel.isLoading(selection), items.isEmpty {
            ProgressView()
                .tint(.primary)
                .padding(.top, 4)
        } else if viewModel.didFail(selection), items.isEmpty {
            ContentUnavailableView(
                "Cannot load \(selection.title.lowercased())",
                systemImage: "exclamationmark.triangle",
                description: Text("Please try again in a moment.")
            )
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
        } else if items.isEmpty {
            ContentUnavailableView(
                "No \(selection.title.lowercased()) found",
                systemImage: selection.emptySystemImage,
                description: Text("Try a different search term.")
            )
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ExploreItemRowView(
                        item: item,
                        selection: selection,
                        statuses: viewModel.statuses(for: item, selection: selection),
                        isLoadingStatuses: viewModel.isLoadingStatuses(for: item, selection: selection)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onFirstAppear(id: "\(item.id)-\(viewModel.refreshToken(for: selection))") {
                        await viewModel.loadStatusesIfNeeded(
                            for: item,
                            selection: selection,
                            using: appState
                        )
                    }

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private func search() {
        isSearchFieldFocused = false

        Task {
            await viewModel.search(selection: selection, query: query, using: appState)
        }
    }

    private func clearSearch() {
        query = ""
        isSearchFieldFocused = true
    }

    private func handleQueryChange(from oldValue: String, to newValue: String) {
        guard !oldValue.isEmpty, newValue.isEmpty else {
            return
        }

        Task {
            await viewModel.search(selection: selection, query: "", using: appState)
        }
    }
}
