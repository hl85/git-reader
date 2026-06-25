import SwiftUI

struct AccountManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = AccountManager.shared
    @State private var accountToDelete: AccountInfo?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if accountManager.accounts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Spacer()
                            Text("account_empty_icon".localized)
                                .font(.system(size: 48))
                            Text("no_accounts_logged_in".localized)
                                .font(.headline)
                                .foregroundStyle(ClaudeColors.textSecondary)
                            Text("no_accounts_logged_in_desc".localized)
                                .font(.subheadline)
                                .foregroundStyle(ClaudeColors.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section(header: Text("logged_in_accounts".localized)) {
                        ForEach(accountManager.accounts) { account in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.username)
                                        .font(.headline)
                                        .foregroundStyle(ClaudeColors.text)

                                    Text(account.platform.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(ClaudeColors.textSecondary)

                                    if let serverURL = account.serverURL {
                                        Text(serverURL)
                                            .font(.caption)
                                            .foregroundStyle(ClaudeColors.textMuted)
                                    }
                                }

                                Spacer()

                                Button(role: .destructive, action: {
                                    accountToDelete = account
                                    showDeleteConfirmation = true
                                }) {
                                    Text("logout".localized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("account_management_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) { dismiss() }
                }
            }
            .alert("delete_account_title".localized, isPresented: $showDeleteConfirmation, presenting: accountToDelete) { account in
                Button("delete_account_confirm".localized, role: .destructive) {
                    withAnimation {
                        accountManager.removeAccount(id: account.id)
                    }
                    openRevokeSettings(for: account)
                }
                Button("delete_account_revoke_only".localized) {
                    openRevokeSettings(for: account)
                }
                Button("cancel".localized, role: .cancel) {}
            } message: { account in
                Text("delete_account_message_\(account.platform.rawValue)".localized)
            }
        }
    }

    private func openRevokeSettings(for account: AccountInfo) {
        let url: URL?
        switch account.platform {
        case .github:
            url = URL(string: "https://github.com/settings/applications")
        case .gitlab:
            if let serverURL = account.serverURL {
                url = URL(string: "\(serverURL)/-/profile/applications")
            } else {
                url = URL(string: "https://gitlab.com/-/profile/applications")
            }
        case .generic:
            url = nil
        }
        if let url {
            UIApplication.shared.open(url)
        }
    }
}
