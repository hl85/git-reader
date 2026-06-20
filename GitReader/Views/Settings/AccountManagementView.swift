import SwiftUI

struct AccountManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = AccountManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                if accountManager.accounts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Spacer()
                            Text("👤")
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
                                    withAnimation {
                                        accountManager.removeAccount(id: account.id)
                                    }
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
        }
    }
}
