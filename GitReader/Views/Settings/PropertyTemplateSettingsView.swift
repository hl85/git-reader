import SwiftUI
import Yams

struct PropertyTemplateSettingsView: View {
    @StateObject private var manager = PropertyTemplateManager.shared
    @State private var yamlText: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // YAML 模板编辑卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YAML 模板")
                            .font(ClaudeTypography.navTitleFont)
                            .foregroundStyle(ClaudeColors.textSecondary)
                        Spacer()
                    }
                    
                    TextEditor(text: $yamlText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                        .padding(12)
                        .background(ClaudeColors.cardBackground)
                        .cornerRadius(ClaudeTypography.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                                .stroke(ClaudeColors.border, lineWidth: ClaudeTypography.cardBorderWidth)
                        )
                        .onChange(of: yamlText) { oldValue, newValue in
                            validateAndSave(newValue)
                        }
                    
                    Text("提示：支持的类型 (type) 包括：date (日期), enum (单选), tags (标签), text (单行文本)")
                        .font(ClaudeTypography.captionFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .padding(.top, 2)
                }
                .padding(ClaudeTypography.cardPadding)
                .background(ClaudeColors.background)
                
                if let error = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ClaudeColors.accent)
                            Text("格式错误")
                                .font(ClaudeTypography.navTitleFont)
                                .foregroundStyle(ClaudeColors.accent)
                        }
                        Text(error)
                            .font(ClaudeTypography.monoCaptionFont)
                            .foregroundStyle(ClaudeColors.textSecondary)
                    }
                    .padding(ClaudeTypography.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ClaudeColors.cardBackground)
                    .cornerRadius(ClaudeTypography.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                            .stroke(ClaudeColors.accent.opacity(0.3), lineWidth: ClaudeTypography.cardBorderWidth)
                    )
                    .padding(.horizontal, ClaudeTypography.cardPadding)
                }
                
                // 预览卡片
                VStack(alignment: .leading, spacing: 16) {
                    Text("预览")
                        .font(ClaudeTypography.navTitleFont)
                        .foregroundStyle(ClaudeColors.textSecondary)
                        .padding(.bottom, 4)
                    
                    ForEach(manager.fields) { field in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(field.name)
                                    .font(ClaudeTypography.bodyFont.weight(.semibold))
                                    .foregroundStyle(ClaudeColors.text)
                                Spacer()
                                Text(field.type.rawValue)
                                    .font(ClaudeTypography.codeCaptionFont)
                                    .foregroundStyle(ClaudeColors.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(ClaudeColors.tagBackground)
                                    .cornerRadius(4)
                            }
                            
                            if let options = field.options {
                                Text("选项: \(options.joined(separator: ", "))")
                                    .font(ClaudeTypography.captionFont)
                                    .foregroundStyle(ClaudeColors.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(ClaudeColors.cardBackground)
                        .cornerRadius(ClaudeTypography.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: ClaudeTypography.cardCornerRadius)
                                .stroke(ClaudeColors.border, lineWidth: ClaudeTypography.cardBorderWidth)
                        )
                    }
                }
                .padding(ClaudeTypography.cardPadding)
                .background(ClaudeColors.background)
            }
            .padding(.vertical, 16)
        }
        .background(ClaudeColors.background)
        .navigationTitle("属性模板管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            yamlText = manager.templateYAML
        }
    }
    
    private func validateAndSave(_ yaml: String) {
        do {
            let decoder = Yams.YAMLDecoder()
            _ = try decoder.decode([PropertyField].self, from: yaml)
            errorMessage = nil
            manager.templateYAML = yaml
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
