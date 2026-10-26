//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DirectMessageRecipientsView: View {
    @Bindable var model: DirectConversationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.recipients.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.recipients, id: \.uniquenessKey) { user in
                            HStack(spacing: 6) {
                                AsyncAvatarView(urlString: user.avatarUrl, size: 28)
                                Text(user.name?.nilIfEmpty ?? user.userName ?? "Unknown")
                                    .font(.subheadline)

                                if model.isDraft {
                                    Button {
                                        model.removeRecipient(user)
                                    } label: {
                                        Label("Remove \(user.name ?? user.userName ?? "recipient")", systemImage: "xmark.circle.fill")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(model.isBusy)
                                }
                            }
                            .padding(8)
                            .background(.quaternary, in: .capsule)
                        }
                    }
                }
                .padding(.horizontal)
            }

            if model.isDraft {
                HStack(spacing: 10) {
                    Text("To:")

                    TextField("Search recipients", text: $model.userQuery, prompt: Text(""))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search recipients")
                        .disabled(!model.isReady || model.isBusy)
                }
                .font(.body)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .frame(minHeight: 52)
                .background(Color(uiColor: .secondarySystemBackground))

                if model.recipients.isEmpty {
                    Text("Choose recipients to start writing a message.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if !model.searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(model.searchResults, id: \.uniquenessKey) { user in
                                Button {
                                    model.addRecipient(user)
                                } label: {
                                    HStack {
                                        AsyncAvatarView(urlString: user.avatarUrl, size: 36)
                                        VStack(alignment: .leading) {
                                            Text(user.name?.nilIfEmpty ?? user.userName ?? "Unknown")
                                            Text(user.account ?? user.userName ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                        Image(systemName: "plus.circle")
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .disabled(model.isBusy || model.recipients.count >= AppConstants.DirectMessages.maximumRecipients)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
