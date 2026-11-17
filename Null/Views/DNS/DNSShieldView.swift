import SwiftUI

struct DNSShieldView: View {
    @EnvironmentObject var store: FilterStore

    @State private var showXMLPreview = false
    @State private var exportedProfileURL: URL?

    private var config: DNSConfiguration {
        store.dnsConfig
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerRow

                activeEndpointSummaryCard

                providerSelectionCard

                if config.activePreset.supportsCustomProfileID {
                    customProfileIDCard
                }

                if config.selectedProviderID == "custom-endpoint" {
                    customEndpointEditorCard
                }

                networkRulesCard

                deploymentActionsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showXMLPreview) {
            NavigationStack {
                ZStack {
                    NullTheme.bgBase.ignoresSafeArea()
                    ScrollView {
                        Text(store.dnsService.buildMobileConfigXML(for: config))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(NullTheme.emerald)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .navigationTitle("MobileConfig 描述檔原始碼")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("關閉") { showXMLPreview = false }
                            .foregroundStyle(NullTheme.emerald)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            exportedProfileURL = store.dnsService.exportMobileConfigURL(for: config)
        }
        .onChange(of: store.dnsConfig) { _, newValue in
            exportedProfileURL = store.dnsService.exportMobileConfigURL(for: newValue)
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("全機 DNS 盾")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                Text("跨所有 App 阻擋廣告、手遊插頁與遙測追蹤")
                    .font(.caption)
                    .foregroundStyle(NullTheme.textSecondary)
            }
            Spacer()
            NullStatusPill(
                text: store.dnsService.isDirectExtensionEnabled ? "API 已直連" : "描述檔模式就緒",
                color: store.dnsService.isDirectExtensionEnabled ? NullTheme.emerald : NullTheme.cyan
            )
        }
    }

    private var activeEndpointSummaryCard: some View {
        NullGlassCard(highlightColor: NullTheme.cyan) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("當前加密上行端點", systemImage: "lock.icloud.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(config.resolvedProtocol.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NullTheme.bgBase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(NullTheme.cyan, in: Capsule())
                }

                Text(config.resolvedProtocol == .https ? config.resolvedDoHURL : config.resolvedDoTHost)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(NullTheme.emerald)
                    .textSelection(.enabled)

                if !config.resolvedServerAddresses.isEmpty {
                    Text("Bootstrap IP：\(config.resolvedServerAddresses.joined(separator: " · "))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(NullTheme.textSecondary)
                }
            }
        }
    }

    private var providerSelectionCard: some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("選擇加密 DNS 過濾核心")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                ForEach(DNSProviderPreset.catalog) { preset in
                    let isSelected = config.selectedProviderID == preset.id
                    Button {
                        store.updateDNSConfig { $0.selectedProviderID = preset.id }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? NullTheme.emerald : NullTheme.textMuted)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(preset.badge)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(isSelected ? NullTheme.bgBase : NullTheme.cyan)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            isSelected ? NullTheme.emerald : NullTheme.cyan.opacity(0.14),
                                            in: Capsule()
                                        )
                                }
                                Text(preset.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(NullTheme.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? NullTheme.emerald.opacity(0.10) : Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isSelected ? NullTheme.emerald.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customProfileIDCard: some View {
        NullGlassCard(highlightColor: NullTheme.emerald) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(config.activePreset.name) 專屬設定檔 ID")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                TextField(
                    config.activePreset.profilePlaceholder,
                    text: Binding(
                        get: { config.customProfileID },
                        set: { val in store.updateDNSConfig { $0.customProfileID = val } }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var customEndpointEditorCard: some View {
        NullGlassCard(highlightColor: NullTheme.emerald) {
            VStack(alignment: .leading, spacing: 10) {
                Text("自訂加密 DNS 伺服器參數")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Picker("協定", selection: Binding(
                    get: { config.customProtocolMode },
                    set: { val in store.updateDNSConfig { $0.customProtocolMode = val } }
                )) {
                    ForEach(DNSProtocolMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if config.customProtocolMode == .https {
                    TextField("https://your-dns.example/dns-query", text: Binding(
                        get: { config.customDoHURL },
                        set: { val in store.updateDNSConfig { $0.customDoHURL = val } }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    TextField("dns.example.com", text: Binding(
                        get: { config.customDoTHost },
                        set: { val in store.updateDNSConfig { $0.customDoTHost = val } }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                TextField("伺服器 IP（逗號分隔，可留空）", text: Binding(
                    get: { config.customIPsText },
                    set: { val in store.updateDNSConfig { $0.customIPsText = val } }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var networkRulesCard: some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("On-Demand 智慧觸發規則")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Picker("套用網路", selection: Binding(
                    get: { config.networkScope },
                    set: { val in store.updateDNSConfig { $0.networkScope = val } }
                )) {
                    ForEach(DNSNetworkScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text("排除特定 Wi-Fi 名稱（SSID，逗號分隔）")
                        .font(.caption2)
                        .foregroundStyle(NullTheme.textSecondary)
                    TextField("例如：Office-Intranet, Home-NAS", text: Binding(
                        get: { config.excludedSSIDsText },
                        set: { val in store.updateDNSConfig { $0.excludedSSIDsText = val } }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption)
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var deploymentActionsCard: some View {
        NullGlassCard(highlightColor: NullTheme.emerald) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("套用至 iPhone 系統")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    NullStatusPill(text: "免付費簽章可用", color: NullTheme.emerald)
                }

                Text("透過 iOS 原生加密 DNS 描述檔（.mobileconfig），無需 VPN 耗電或付費開發者憑證，即可跨 App（新聞、遊戲、社群）全域封鎖廣告伺服器。")
                    .font(.caption2)
                    .foregroundStyle(NullTheme.textSecondary)

                Button {
                    store.dnsService.launchOneTapProfileInstaller(for: config)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("一鍵安裝系統 DNS 描述檔（推薦）")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(NullTheme.bgBase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(NullTheme.accentGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let msg = store.dnsService.profileInstallMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(NullTheme.emerald)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NullTheme.emerald.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 10) {
                    if let url = exportedProfileURL {
                        ShareLink(item: url) {
                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.up")
                                Text("匯出檔案")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                    }

                    Button {
                        showXMLPreview = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.plaintext")
                            Text("檢視 XML")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NullTheme.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(NullTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 6) {
                    Text("進階：直接呼叫 NetworkExtension API（適用開發者憑證 / TrollStore）")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NullTheme.textSecondary)

                    Button {
                        Task { await store.dnsService.applyDirectNetworkExtension(config: config) }
                    } label: {
                        HStack {
                            if store.dnsService.isWorking {
                                ProgressView().controlSize(.mini).tint(.white)
                            } else {
                                Image(systemName: "bolt.horizontal.circle")
                            }
                            Text("嘗試系統 API 直接啟用")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }

                    Text(store.dnsService.directExtensionStatus)
                        .font(.caption2)
                        .foregroundStyle(NullTheme.textMuted)
                }
            }
        }
    }
}
