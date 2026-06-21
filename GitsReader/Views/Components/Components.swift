import SwiftUI

// MARK: - Card Style Modifier

/// Claude 风格卡片：无阴影、微圆角、细边框
struct ClaudeCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(ClaudeTypography.cardPadding)
            .background(ClaudeColors.cardBackground)
            .cornerRadius(ClaudeTypography.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                    .stroke(ClaudeColors.border, lineWidth: ClaudeTypography.cardBorderWidth)
            )
    }
}

extension View {
    func claudeCard() -> some View {
        modifier(ClaudeCardStyle())
    }
}

// MARK: - Toast Component

struct ToastView: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            Spacer()
            if isPresented {
                Text(message)
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(ClaudeColors.background)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ClaudeColors.text)
                    .cornerRadius(20)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPresented)
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    let lastSyncTime: String?
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.caption2)
            Text(lastSyncTime.map { "offline_mode_with_time".localized(arguments: $0) } ?? "offline_mode".localized)
                .font(.system(.caption2, design: .monospaced))
        }
        .foregroundStyle(ClaudeColors.lightAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            Color(lightScheme: Color(red: 0.961, green: 0.941, blue: 0.910),
                  darkScheme: Color(red: 0.165, green: 0.157, blue: 0.125))
        )
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 48))
                .opacity(0.6)

            Text(title)
                .font(ClaudeTypography.titleFont)
                .foregroundStyle(ClaudeColors.text)

            Text(description)
                .font(ClaudeTypography.bodyFont)
                .foregroundStyle(ClaudeColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .padding(60)
    }
}

// MARK: - Sync Loader

struct SyncLoader: View {
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("syncing".localized)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(ClaudeColors.textSecondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image Error Placeholder

struct ImagePlaceholder: View {
    let filename: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(ClaudeColors.textMuted)
            if let filename = filename {
                Text(filename)
                    .font(ClaudeTypography.codeCaptionFont)
                    .foregroundStyle(ClaudeColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(ClaudeColors.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ClaudeColors.border, lineWidth: 1)
        )
    }
}

// MARK: - WikiLink Text Style

struct WikiLinkStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(ClaudeColors.link)
            .underline(pattern: .solid, color: ClaudeColors.link.opacity(0.3))
    }
}

extension View {
    func wikiLinkStyle() -> some View {
        modifier(WikiLinkStyle())
    }
}
