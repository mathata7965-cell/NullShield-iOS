import SwiftUI
import UIKit

struct ShieldDashboardView: View {
    @EnvironmentObject var store: FilterStore
    @Binding var selectedTab: Int
    @Binding var labSubTab: Int

    @State private var showSetupSteps = false

    private var activeCategoryCount: Int {
        store.categories.filter(\.isEnabled).count
    }

    private var ruleCapacityProgress: Double {
        min(1.0, Double(store.totalCompiledRuleCount) / 150_000.0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerBar

                ZeroRingView(
                    isActive: store.isMasterShieldEnabled,
                    ruleCount: store.totalCompiledRuleCount,
                    presetTitle: store.activePreset?.title ?? "自訂配置"
                ) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                        store.toggleMasterShield()
                    }
                }
                .padding(.vertical, 4)

                presetMatrixSection

                safariExtensionCard

                protectionStackCard

                telemetrySummaryCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.safariService.refreshStatus()
            await store.dnsService.checkDirectNetworkExtensionStatus()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            NullGlyphBadge(size: 38, isActive: store.isMasterShieldEnabled)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Null")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("零噪盾")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NullTheme.emerald)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(NullTheme.emerald.opacity(0.14), in: Capsule())
                }
                Text("Safari 內容阻擋 · 全機 DNS · 追蹤 X-Ray")
                    .font(.caption)
                    .foregroundStyle(NullTheme.textSecondary)
            }

            Spacer()

            Button {
                labSubTab = 1
                selectedTab = 3
            } label: {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.headline)
                    .foregroundStyle(NullTheme.cyan)
                    .padding(10)
                    .background(NullTheme.cyan.opacity(0.12), in: Circle())
                    .overlay(Circle().strokeBorder(NullTheme.cyan.opacity(0.3), lineWidth: 0.8))
            }
            .accessibilityLabel("開啟 X-Ray 穿透雷達")
        }
    }

    private var presetMatrixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("防護情境模式")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(activeCategoryCount)/\(store.categories.count) 模組啟用")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NullTheme.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ShieldPreset.allCases) { preset in
                    let isSelected = store.activePreset == preset && store.isMasterShieldEnabled
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            store.applyPreset(preset)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: preset.iconName)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(isSelected ? NullTheme.emerald : NullTheme.textSecondary)
                                Spacer()
                                Text(preset.badgeText)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isSelected ? NullTheme.bgBase : NullTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        isSelected ? NullTheme.emerald : Color.white.opacity(0.10),
                                        in: Capsule()
                                    )
                            }
                            Text(preset.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(preset.subtitle)
                                .font(.caption2)
                                .foregroundStyle(NullTheme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? NullTheme.emerald.opacity(0.12) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    isSelected ? NullTheme.emerald.opacity(0.65) : Color.white.opacity(0.10),
                                    lineWidth: isSelected ? 1.3 : 0.8
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var safariExtensionCard: some View {
        NullGlassCard(highlightColor: safariCardTint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Label {
                        Text("Safari 內容阻擋器")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "safari.fill")
                            .foregroundStyle(safariCardTint)
                    }

                    Spacer()

                    if !store.safariService.hasEmbeddedExtension {
                        NullStatusPill(text: "單一 App 版", color: NullTheme.amber, icon: "puzzlepiece")
                    } else if store.safariService.isExtensionEnabled == true {
                        NullStatusPill(text: "已保護 Safari", color: NullTheme.emerald, icon: "checkmark")
                    } else {
                        NullStatusPill(text: "待開啟延伸功能", color: NullTheme.amber, icon: "exclamationmark.triangle.fill")
                    }
                }

                Text(store.safariService.lastStatusMessage)
                    .font(.caption)
                    .foregroundStyle(NullTheme.textSecondary)

                // Safari 150k rule slot usage bar
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("WebKit 規則槽容量")
                            .font(.caption2)
                            .foregroundStyle(NullTheme.textMuted)
                        Spacer()
                        Text("\(store.totalCompiledRuleCount) / 150,000")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(NullTheme.cyan)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(NullTheme.accentGradient)
                                .frame(width: max(8, geo.size.width * ruleCapacityProgress))
                        }
                    }
                    .frame(height: 6)
                }

                HStack(spacing: 10) {
                    Button {
                        store.forceSafariReload()
                    } label: {
                        HStack(spacing: 6) {
                            if store.safariService.isReloading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(NullTheme.bgBase)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("重載 Safari 規則")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(NullTheme.bgBase)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(NullTheme.accentGradient, in: Capsule())
                    }
                    .disabled(store.safariService.isReloading)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSetupSteps.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                            Text(showSetupSteps ? "收合步驟" : "開啟步驟教學")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    Spacer()

                    if store.stats.lastCompileDurationMs > 0 {
                        Text("\(store.stats.lastCompileDurationMs) ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NullTheme.textMuted)
                    }
                }

                if showSetupSteps {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider().overlay(Color.white.opacity(0.12))
                        stepRow("1", "開啟 iPhone「設定」→ 向下滑找到「App」→「Safari」")
                        stepRow("2", "點選「延伸功能」→ 找到「Null Safari 盾」並開啟")
                        stepRow("3", "回到 Null 點擊「重載 Safari 規則」確認亮起綠燈")
                        if !store.safariService.appGroupSyncActive && store.safariService.hasEmbeddedExtension {
                            Text("提示：免費 Apple ID 側載不會授權 App Group，因此 Safari 外掛會持續使用內建精選 420+ 核心規則；你的自訂規則與遠端訂閱清單仍會在「實驗室 → Stealth 無痕瀏覽器」中 100% 即時生效。")
                                .font(.caption2)
                                .foregroundStyle(NullTheme.amber.opacity(0.9))
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func stepRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.caption2.weight(.bold))
                .foregroundStyle(NullTheme.bgBase)
                .frame(width: 16, height: 16)
                .background(NullTheme.emerald, in: Circle())
            Text(text)
                .font(.caption2)
                .foregroundStyle(NullTheme.textSecondary)
        }
    }

    private var safariCardTint: Color {
        if !store.safariService.hasEmbeddedExtension { return NullTheme.amber }
        return store.safariService.isExtensionEnabled == true ? NullTheme.emerald : NullTheme.amber
    }

    private var protectionStackCard: some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("三層協同防禦架構")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Button {
                    selectedTab = 2
                } label: {
                    stackRow(
                        icon: "network.badge.shield.half.filled",
                        iconColor: NullTheme.cyan,
                        title: "全機加密 DNS 盾（跨 App 去廣告）",
                        detail: "\(store.dnsConfig.activePreset.name) · \(store.dnsConfig.resolvedProtocol.rawValue)",
                        badge: store.dnsService.isDirectExtensionEnabled ? "API 已啟用" : "前往安裝描述檔"
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.white.opacity(0.08))

                Button {
                    selectedTab = 1
                } label: {
                    stackRow(
                        icon: "slider.horizontal.3",
                        iconColor: NullTheme.emerald,
                        title: "AdGuard 語法規則與訂閱中心",
                        detail: "\(store.customRules.filter(\.isEnabled).count) 條自訂規則 · \(store.subscriptions.filter(\.isEnabled).count) 個訂閱清單",
                        badge: "管理規則"
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.white.opacity(0.08))

                Button {
                    labSubTab = 0
                    selectedTab = 3
                } label: {
                    stackRow(
                        icon: "shield.checkerboard",
                        iconColor: Color(red: 0.62, green: 0.54, blue: 1.0),
                        title: "Stealth 無痕瀏覽器 & 實測靶場",
                        detail: "即時編譯所有自訂／訂閱規則・自動剝離追蹤 URL",
                        badge: "立即實測"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stackRow(icon: String, iconColor: Color, title: String, detail: String, badge: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(NullTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(iconColor)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NullTheme.textMuted)
            }
        }
    }

    private var telemetrySummaryCard: some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("淨化遙測累計（零雲端上傳・純本機紀錄）")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }

                HStack(spacing: 10) {
                    metricTile(value: "\(store.stats.totalBrowserBlocked)", label: "攔截廣告／追蹤", color: NullTheme.emerald)
                    metricTile(value: store.stats.estimatedSavedLabel, label: "估計節省流量", color: NullTheme.cyan)
                    metricTile(value: "\(store.stats.totalXRayScans)", label: "X-Ray 掃描", color: Color(red: 0.65, green: 0.56, blue: 1.0))
                    metricTile(value: "\(store.stats.totalSanitizedLinks)", label: "網址淨化", color: NullTheme.amber)
                }
            }
        }
    }

    private func metricTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NullTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
