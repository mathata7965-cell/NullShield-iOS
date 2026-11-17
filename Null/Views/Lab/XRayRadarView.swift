import SwiftUI

struct XRayRadarView: View {
    @EnvironmentObject var store: FilterStore

    @State private var domainInput: String = "googleads.g.doubleclick.net"
    @State private var isScanning: Bool = false
    @State private var scanResult: XRayScanResult?

    private let quickSamples = [
        "googleads.g.doubleclick.net",
        "pixel.facebook.com",
        "analytics.tiktok.com",
        "onead.com.tw",
        "apple.com"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                scannerInputCard

                if isScanning {
                    NullGlassCard {
                        HStack(spacing: 12) {
                            ProgressView().tint(NullTheme.cyan)
                            Text("正在並發探測標準 DNS 與 AdGuard DNS 解析鏈...")
                                .font(.caption)
                                .foregroundStyle(NullTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let res = scanResult {
                    verdictSummaryCard(res)
                    dnsComparisonCard(res)

                    if let intel = res.matchedIntel ?? res.cnameCloakingVendor {
                        intelHighlightCard(intel, isCloaked: res.matchedIntel == nil && res.cnameCloakingVendor != nil)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var scannerInputCard: some View {
        NullGlassCard(highlightColor: NullTheme.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("DNS & CNAME 追蹤穿透雷達", systemImage: "waveform.path.ecg")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    NullStatusPill(text: "即時 DoH 對比", color: NullTheme.cyan)
                }

                Text("同時向未過濾標準 DNS 與過濾 DNS 發起加密查詢，揭露 CNAME 偽裝追蹤與本機規則命中狀態。")
                    .font(.caption2)
                    .foregroundStyle(NullTheme.textSecondary)

                HStack(spacing: 8) {
                    TextField("輸入網域或貼上網址", text: $domainInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.callout, design: .monospaced))
                        .padding(10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onSubmit { runScan() }

                    Button {
                        runScan()
                    } label: {
                        Text("掃描")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NullTheme.bgBase)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(NullTheme.accentGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(isScanning || domainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(quickSamples, id: \.self) { sample in
                            Button {
                                domainInput = sample
                                runScan()
                            } label: {
                                Text(sample)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(NullTheme.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(NullTheme.cyan.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private func verdictSummaryCard(_ res: XRayScanResult) -> some View {
        let protected = res.isProtectedLocally || res.isProtectedByDNS
        return NullGlassCard(highlightColor: protected ? NullTheme.emerald : NullTheme.amber) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(res.queryDomain)
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    NullStatusPill(
                        text: protected ? "已被防線攔截" : "目前放行",
                        color: protected ? NullTheme.emerald : NullTheme.amber
                    )
                }

                HStack(spacing: 8) {
                    statusChip(
                        title: "本機規則引擎",
                        detail: res.isProtectedLocally ? (res.matchedLocalCategories.first ?? "自訂規則命中") : "未命中封鎖清單",
                        active: res.isProtectedLocally
                    )
                    statusChip(
                        title: "全機 DNS 盾",
                        detail: res.isProtectedByDNS ? "已歸零阻擋 (0.0.0.0)" : "正常放行解析",
                        active: res.isProtectedByDNS
                    )
                }

                HStack(spacing: 8) {
                    let inCustom = store.customRules.contains { $0.rawText.contains(res.queryDomain) }
                    Button {
                        if !inCustom {
                            store.addCustomRule(rawText: "||\(res.queryDomain)^", note: "X-Ray 雷達封鎖")
                        }
                    } label: {
                        Text(inCustom ? "已在自訂封鎖中" : "+ 加入自訂封鎖")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(inCustom ? NullTheme.emerald : NullTheme.bgBase)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(inCustom ? NullTheme.emerald.opacity(0.14) : NullTheme.emerald, in: Capsule())
                    }
                    .disabled(inCustom)

                    let inAllow = store.allowlistDomains.contains(res.queryDomain)
                    Button {
                        if !inAllow {
                            store.addAllowlistDomain(res.queryDomain)
                        }
                    } label: {
                        Text(inAllow ? "已在白名單" : "加入白名單例外")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NullTheme.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(NullTheme.cyan.opacity(0.12), in: Capsule())
                    }
                    .disabled(inAllow)
                }
            }
        }
    }

    private func statusChip(title: String, detail: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(NullTheme.textMuted)
            Text(detail)
                .font(.caption.weight(.bold))
                .foregroundStyle(active ? NullTheme.emerald : NullTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func dnsComparisonCard(_ res: XRayScanResult) -> some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("DoH 解析鏈實測對比")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                probeSection(res.standardProbe, accent: NullTheme.cyan)
                Divider().overlay(Color.white.opacity(0.08))
                probeSection(res.filteredProbe, accent: res.filteredProbe.isBlockedByDNS ? NullTheme.emerald : NullTheme.amber)
            }
        }
    }

    private func probeSection(_ probe: DNSProbeOutcome, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(probe.providerName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                Spacer()
                Text("\(probe.latencyMs) ms")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(NullTheme.textMuted)
            }

            if let err = probe.errorMessage {
                Text("查詢失敗：\(err)")
                    .font(.caption2)
                    .foregroundStyle(NullTheme.crimson)
            } else if probe.answers.isEmpty {
                Text(probe.isBlockedByDNS ? "結果：已攔截（NXDOMAIN / 空記錄）" : "無 A 記錄回傳")
                    .font(.caption2.monospaced())
                    .foregroundStyle(probe.isBlockedByDNS ? NullTheme.emerald : NullTheme.textSecondary)
            } else {
                ForEach(probe.answers.prefix(5)) { rec in
                    HStack(spacing: 6) {
                        Text(rec.typeName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(NullTheme.bgBase)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accent, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text(rec.data)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("TTL \(rec.ttl)s")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NullTheme.textMuted)
                    }
                }
            }
        }
    }

    private func intelHighlightCard(_ intel: TrackerIntelEntry, isCloaked: Bool) -> some View {
        NullGlassCard(highlightColor: NullTheme.crimson) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: isCloaked ? "theatermasks.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(NullTheme.crimson)
                    Text(isCloaked ? "偵測到 CNAME 偽裝追蹤！" : "追蹤商識別：\(intel.vendor)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Text("\(intel.domain) · \(intel.category)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NullTheme.amber)
                Text(intel.summary)
                    .font(.caption2)
                    .foregroundStyle(NullTheme.textSecondary)
            }
        }
    }

    private func runScan() {
        let query = domainInput
        isScanning = true
        Task {
            let result = await DoHXRayService.scanDomain(
                query,
                categories: store.categories,
                customRules: store.customRules,
                intelCatalog: store.trackerIntel
            )
            await MainActor.run {
                scanResult = result
                isScanning = false
                store.recordXRayScan()
            }
        }
    }
}
