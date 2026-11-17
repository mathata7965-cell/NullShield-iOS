import SwiftUI

struct CustomRulesSheet: View {
    @EnvironmentObject var store: FilterStore
    @Environment(\.dismiss) private var dismiss

    @State private var segment = 0
    @State private var newRuleInput = ""
    @State private var newRuleNote = ""
    @State private var newAllowDomain = ""

    private var liveParsedPreview: String {
        let trimmed = newRuleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "支援格式：||ads.example.com^、@@||ok.com^、##.ad-box、0.0.0.0 bad.com" }
        if let dto = AdBlockCompiler.parseSingleLine(trimmed) {
            if dto.action.type == "css-display-none", let sel = dto.action.selector {
                return "✓ 合法元素隱藏規則 → CSS: \(sel)"
            } else if dto.action.type == "ignore-previous-rules" {
                return "✓ 合法白名單例外規則 → Regex: \(dto.trigger.urlFilter)"
            } else {
                return "✓ 合法阻擋規則 → Regex: \(dto.trigger.urlFilter)"
            }
        }
        return "⚠︎ 無法編譯為 WebKit 規則（請檢查網域拼寫或語法）"
    }

    private var isRuleInputValid: Bool {
        AdBlockCompiler.parseSingleLine(newRuleInput) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NullAmbientBackground(isActive: store.isMasterShieldEnabled)

                VStack(spacing: 14) {
                    Picker("規則模式", selection: $segment) {
                        Text("自訂封鎖規則").tag(0)
                        Text("網站白名單").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if segment == 0 {
                        customRulesContent
                    } else {
                        allowlistContent
                    }
                }
                .padding(.top, 10)
            }
            .navigationTitle("規則語法與白名單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(NullTheme.emerald)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var customRulesContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                NullGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("新增 AdGuard / EasyList 規則")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)

                        TextField("例如：||ads.example.com^$third-party", text: $newRuleInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.callout, design: .monospaced))
                            .padding(10)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        TextField("備註（選填）", text: $newRuleNote)
                            .font(.caption)
                            .padding(10)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text(liveParsedPreview)
                            .font(.caption2.monospaced())
                            .foregroundStyle(isRuleInputValid ? NullTheme.emerald : NullTheme.amber)

                        HStack {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    quickChip("||domain.com^") { newRuleInput = "||ads.example.com^" }
                                    quickChip("##.ad-banner") { newRuleInput = "##.ad-banner" }
                                    quickChip("$third-party") { newRuleInput = "||tracker.example.com^$third-party,script" }
                                }
                            }
                            Button("新增") {
                                store.addCustomRule(rawText: newRuleInput, note: newRuleNote)
                                newRuleInput = ""
                                newRuleNote = ""
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NullTheme.bgBase)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isRuleInputValid ? NullTheme.emerald : Color.white.opacity(0.25), in: Capsule())
                            .disabled(!isRuleInputValid)
                        }
                    }
                }

                NullGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("目前自訂規則（\(store.customRules.count)）")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)

                        if store.customRules.isEmpty {
                            Text("尚未建立自訂規則")
                                .font(.caption)
                                .foregroundStyle(NullTheme.textMuted)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(Array(store.customRules.enumerated()), id: \.element.id) { idx, rule in
                                if idx > 0 { Divider().overlay(Color.white.opacity(0.08)) }
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rule.rawText)
                                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(rule.isEnabled ? .white : NullTheme.textMuted)
                                        if !rule.note.isEmpty {
                                            Text(rule.note)
                                                .font(.caption2)
                                                .foregroundStyle(NullTheme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { rule.isEnabled },
                                        set: { _ in store.toggleCustomRule(rule.id) }
                                    ))
                                    .labelsHidden()
                                    .tint(NullTheme.emerald)

                                    Button(role: .destructive) {
                                        store.deleteCustomRules(at: IndexSet(integer: idx))
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(NullTheme.crimson)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var allowlistContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                NullGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("加入網域白名單（完全放行）")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("若特定網站因過度攔截而無法正常結帳或登入，可將該網域加入例外清單。")
                            .font(.caption2)
                            .foregroundStyle(NullTheme.textSecondary)

                        HStack(spacing: 8) {
                            TextField("例如：example.com", text: $newAllowDomain)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.callout, design: .monospaced))
                                .padding(10)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button("加入") {
                                store.addAllowlistDomain(newAllowDomain)
                                newAllowDomain = ""
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NullTheme.bgBase)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(NullTheme.cyan, in: Capsule())
                        }
                    }
                }

                NullGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("已放行網域（\(store.allowlistDomains.count)）")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)

                        if store.allowlistDomains.isEmpty {
                            Text("尚無白名單網域")
                                .font(.caption)
                                .foregroundStyle(NullTheme.textMuted)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(store.allowlistDomains, id: \.self) { domain in
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(NullTheme.cyan)
                                    Text(domain)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button(role: .destructive) {
                                        store.removeAllowlistDomain(domain)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(NullTheme.textMuted)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func quickChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(NullTheme.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(NullTheme.cyan.opacity(0.12), in: Capsule())
        }
    }
}
