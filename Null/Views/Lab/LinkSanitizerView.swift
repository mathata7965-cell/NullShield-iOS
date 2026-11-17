import SwiftUI
import UIKit

struct LinkSanitizerView: View {
    @EnvironmentObject var store: FilterStore
    let onOpenInBrowser: (String) -> Void

    @State private var rawInput: String = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=tracking123&utm_source=ig_web_copy&fbclid=IwAR0xyz999"
    @State private var result: LinkSanitizeResult?
    @State private var copiedBadge = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NullGlassCard(highlightColor: NullTheme.emerald) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("分享連結追蹤碼淨化器", systemImage: "link.badge.plus")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                            NullStatusPill(text: "45+ 追蹤碼特徵", color: NullTheme.emerald)
                        }

                        Text("自動剝離 IG / FB / YouTube / TikTok / 電商分享網址內嵌的個人指紋與廣告歸因參數（utm_*, fbclid, gclid, igshid, si, spm 等）。")
                            .font(.caption2)
                            .foregroundStyle(NullTheme.textSecondary)

                        TextEditor(text: $rawInput)
                            .scrollContentBackground(.hidden)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(height: 82)
                            .padding(8)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        HStack(spacing: 8) {
                            Button {
                                if let clip = UIPasteboard.general.string {
                                    rawInput = clip
                                    runSanitize()
                                }
                            } label: {
                                Label("貼上剪貼簿", systemImage: "doc.on.clipboard")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(NullTheme.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(NullTheme.cyan.opacity(0.12), in: Capsule())
                            }

                            Button {
                                runSanitize()
                            } label: {
                                Text("立即淨化網址")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NullTheme.bgBase)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(NullTheme.accentGradient, in: Capsule())
                            }
                        }
                    }
                }

                if let res = result {
                    NullGlassCard(highlightColor: res.isValid ? NullTheme.emerald : NullTheme.crimson) {
                        VStack(alignment: .leading, spacing: 10) {
                            if !res.isValid {
                                Text("無法辨識為有效網址，請確認內容包含網域名稱。")
                                    .font(.caption)
                                    .foregroundStyle(NullTheme.crimson)
                            } else {
                                HStack {
                                    Text("已淨化網址")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    NullStatusPill(
                                        text: res.strippedParams.isEmpty ? "原本即為純淨網址" : "已移除 \(res.strippedParams.count) 個追蹤參數",
                                        color: res.strippedParams.isEmpty ? NullTheme.cyan : NullTheme.emerald
                                    )
                                }

                                Text(res.cleanedURL)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(NullTheme.emerald)
                                    .textSelection(.enabled)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                HStack(spacing: 8) {
                                    Button {
                                        UIPasteboard.general.string = res.cleanedURL
                                        copiedBadge = true
                                        Task {
                                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                                            await MainActor.run { copiedBadge = false }
                                        }
                                    } label: {
                                        Label(copiedBadge ? "已複製！" : "複製乾淨網址", systemImage: copiedBadge ? "checkmark" : "doc.on.doc")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(NullTheme.bgBase)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(NullTheme.emerald, in: Capsule())
                                    }

                                    Button {
                                        onOpenInBrowser(res.cleanedURL)
                                    } label: {
                                        Label("無痕開啟", systemImage: "safari")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(NullTheme.cyan)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(NullTheme.cyan.opacity(0.14), in: Capsule())
                                    }
                                }

                                if !res.strippedParams.isEmpty {
                                    Divider().overlay(Color.white.opacity(0.08))
                                    Text("已清除參數明細")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                    ForEach(res.strippedParams) { param in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text(param.key)
                                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                                .foregroundStyle(NullTheme.amber)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(NullTheme.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(param.reason)
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                if !param.value.isEmpty {
                                                    Text("原值：\(param.value)")
                                                        .font(.caption2.monospaced())
                                                        .foregroundStyle(NullTheme.textMuted)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
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
        .scrollIndicators(.hidden)
        .onAppear {
            if result == nil {
                result = LinkSanitizerService.sanitize(rawInput)
            }
        }
    }

    private func runSanitize() {
        let res = LinkSanitizerService.sanitize(rawInput)
        result = res
        if res.isValid && !res.strippedParams.isEmpty {
            store.recordSanitizedLink()
        }
    }
}
