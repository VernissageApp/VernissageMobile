//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AccountSwitcherSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddAccount = false

    private var sheetBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.08, green: 0.06, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(appState.accounts) { account in
                        Button {
                            appState.activateAccount(id: account.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.displayName?.nilIfEmpty ?? account.userName)
                                        .foregroundStyle(.white)

                                    Text("@\(account.userName) · \(account.instanceURL)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.70))
                                }

                                Spacer()

                                if account.id == appState.activeAccountID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                    .onDelete { offsets in
                        offsets.map { appState.accounts[$0].id }.forEach(appState.removeAccount)
                    }
                } header: {
                    Text("Accounts")
                        .foregroundStyle(.white.opacity(0.62))
                }

                Section {
                    Button {
                        showingAddAccount = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                            Text("Add account")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.blue)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(.white.opacity(0.18))
            .background(sheetBackgroundGradient)
            .navigationTitle("Switch account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(.white)
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountScreen(mode: .additionalAccount) {
                    showingAddAccount = false
                }
                .environment(appState)
            }
        }
        .preferredColorScheme(.dark)
    }
}
