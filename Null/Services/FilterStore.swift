import Foundation
import SwiftUI

@MainActor
final class FilterStore: ObservableObject {
    @Published var isMasterShieldEnabled: Bool = true
    @Published var activePreset: ShieldPreset? = .balanced
    @Published var categories: [FilterCategoryState] = []
    @Published var trackerIntel: [TrackerIntelEntry] = []
    @Published var customRules: [CustomFilterRule] = []
    @Published var allowlistDomains: [String] = []
    @Published var subscriptions: [FilterSubscription] = []
    @Published var dnsConfig: DNSConfiguration = DNSConfiguration()
    @Published var stats: TelemetryStats = TelemetryStats()
    @Published var compiledRuleListJSON: String = "[]"
    @Published var totalCompiledRuleCount: Int = 0
    @Published var isUpdatingSubscriptions: Bool = false
    @Published var updatingSubscriptionID: UUID?

    let safariService = SafariBlockerService()
    let dnsService = DNSProfileService()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let masterEnabled = "null.masterEnabled"
        static let activePreset = "null.activePreset"
        static let categoryToggles = "null.categoryToggles"
        static let customRules = "null.customRules"
        static let allowlist = "null.allowlist"
        static let subscriptions = "null.subscriptions"
        static let dnsConfig = "null.dnsConfig"
        static let stats = "null.stats"
    }

    init() {
        loadBundledFilterPack()
        restorePersistedState()
        rebuildCompiledRules(syncSafari: false)
        Task {
            await safariService.refreshStatus()
            await dnsService.checkDirectNetworkExtensionStatus()
        }
    }

    private func loadBundledFilterPack() {
        guard let url = Bundle.main.url(forResource: "FilterPack", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FilterPackPayloadDTO.self, from: data) else {
            return
        }

        categories = decoded.categories.map { dto in
            FilterCategoryState(
                id: dto.id,
                name: dto.name,
                subtitle: dto.subtitle,
                icon: dto.icon,
                domains: dto.domains,
                rules: dto.rules,
                isEnabled: dto.defaultEnabled
            )
        }
        trackerIntel = decoded.trackerIntel
    }

    private func restorePersistedState() {
        if defaults.object(forKey: Keys.masterEnabled) != nil {
            isMasterShieldEnabled = defaults.bool(forKey: Keys.masterEnabled)
        }

        if let rawPreset = defaults.string(forKey: Keys.activePreset) {
            activePreset = ShieldPreset(rawValue: rawPreset)
        }

        if let savedToggles = defaults.dictionary(forKey: Keys.categoryToggles) as? [String: Bool] {
            for idx in categories.indices {
                if let val = savedToggles[categories[idx].id] {
                    categories[idx].isEnabled = val
                }
            }
        }

        if let data = defaults.data(forKey: Keys.customRules),
           let decoded = try? JSONDecoder().decode([CustomFilterRule].self, from: data) {
            customRules = decoded
        } else {
            customRules = [
                CustomFilterRule(rawText: "||doubleclick.net^", isEnabled: true, note: "範例：攔截 DoubleClick 網域"),
                CustomFilterRule(rawText: "##.ad-sponsored-banner", isEnabled: true, note: "範例：隱藏贊助橫幅元素")
            ]
        }

        if let savedAllow = defaults.stringArray(forKey: Keys.allowlist) {
            allowlistDomains = savedAllow
        }

        if let data = defaults.data(forKey: Keys.subscriptions),
           let decoded = try? JSONDecoder().decode([FilterSubscription].self, from: data) {
            subscriptions = decoded
        } else {
            subscriptions = defaultSubscriptions()
        }

        if let data = defaults.data(forKey: Keys.dnsConfig),
           let decoded = try? JSONDecoder().decode(DNSConfiguration.self, from: data) {
            dnsConfig = decoded
        }

        if let data = defaults.data(forKey: Keys.stats),
           let decoded = try? JSONDecoder().decode(TelemetryStats.self, from: data) {
            stats = decoded
        }
    }

    private func defaultSubscriptions() -> [FilterSubscription] {
        [
            FilterSubscription(
                name: "AdGuard DNS Filter (精簡合併版)",
                urlString: "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt",
                categoryHint: "跨網域廣告、追蹤與 Telemetry 基礎清單"
            ),
            FilterSubscription(
                name: "AdGuard Mobile Ads Filter",
                urlString: "https://filters.adtidy.org/extension/safari/filters/11.txt",
                categoryHint: "專為 iOS 行動網頁與 App 內廣告優化"
            ),
            FilterSubscription(
                name: "EasyPrivacy (Tracker Blocking)",
                urlString: "https://easylist.to/easylist/easyprivacy.txt",
                categoryHint: "全球標準隱私追蹤與分析腳本封鎖"
            ),
            FilterSubscription(
                name: "OISD Small Blocklist",
                urlString: "https://small.oisd.nl/adblock",
                categoryHint: "低誤殺率極簡全能封鎖清單"
            )
        ]
    }

    func saveState() {
        defaults.set(isMasterShieldEnabled, forKey: Keys.masterEnabled)
        defaults.set(activePreset?.rawValue, forKey: Keys.activePreset)

        var toggleMap: [String: Bool] = [:]
        for cat in categories {
            toggleMap[cat.id] = cat.isEnabled
        }
        defaults.set(toggleMap, forKey: Keys.categoryToggles)

        if let data = try? JSONEncoder().encode(customRules) {
            defaults.set(data, forKey: Keys.customRules)
        }
        defaults.set(allowlistDomains, forKey: Keys.allowlist)
        if let data = try? JSONEncoder().encode(subscriptions) {
            defaults.set(data, forKey: Keys.subscriptions)
        }
        if let data = try? JSONEncoder().encode(dnsConfig) {
            defaults.set(data, forKey: Keys.dnsConfig)
        }
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Keys.stats)
        }
    }

    func toggleMasterShield() {
        isMasterShieldEnabled.toggle()
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func applyPreset(_ preset: ShieldPreset) {
        activePreset = preset
        isMasterShieldEnabled = true
        let targetIDs = preset.enabledCategoryIDs
        for idx in categories.indices {
            categories[idx].isEnabled = targetIDs.contains(categories[idx].id)
        }
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func setCategory(_ id: String, enabled: Bool) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].isEnabled = enabled
        activePreset = nil
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func addCustomRule(rawText: String, note: String = "") {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customRules.insert(CustomFilterRule(rawText: trimmed, isEnabled: true, note: note), at: 0)
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func toggleCustomRule(_ id: UUID) {
        guard let idx = customRules.firstIndex(where: { $0.id == id }) else { return }
        customRules[idx].isEnabled.toggle()
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func deleteCustomRules(at offsets: IndexSet) {
        customRules.remove(atOffsets: offsets)
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func addAllowlistDomain(_ rawDomain: String) {
        let normalized = DoHXRayService.normalizeDomain(rawDomain)
        guard AdBlockCompiler.isValidDomainPattern(normalized),
              !allowlistDomains.contains(normalized) else { return }
        allowlistDomains.insert(normalized, at: 0)
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func removeAllowlistDomain(_ domain: String) {
        allowlistDomains.removeAll { $0 == domain }
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func addSubscription(name: String, urlString: String, categoryHint: String = "自訂遠端過濾清單") {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        let sub = FilterSubscription(
            name: trimmedName.isEmpty ? (URL(string: trimmedURL)?.host ?? "自訂訂閱") : trimmedName,
            urlString: trimmedURL,
            categoryHint: categoryHint,
            isEnabled: true
        )
        subscriptions.insert(sub, at: 0)
        saveState()
        Task {
            await updateSubscription(id: sub.id)
        }
    }

    func toggleSubscription(_ id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].isEnabled.toggle()
        saveState()
        if subscriptions[idx].isEnabled && subscriptions[idx].cachedRules.isEmpty {
            Task { await updateSubscription(id: id) }
        } else {
            rebuildCompiledRules(syncSafari: true)
        }
    }

    func deleteSubscriptions(at offsets: IndexSet) {
        subscriptions.remove(atOffsets: offsets)
        saveState()
        rebuildCompiledRules(syncSafari: true)
    }

    func updateSubscription(id: UUID) async {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        guard let url = URL(string: subscriptions[idx].urlString) else {
            subscriptions[idx].lastError = "無效的訂閱網址"
            return
        }

        updatingSubscriptionID = id
        isUpdatingSubscriptions = true
        defer {
            updatingSubscriptionID = nil
            isUpdatingSubscriptions = false
        }

        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NSError(domain: "HTTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                throw NSError(domain: "Encoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法解碼文字內容"])
            }

            let parsed = AdBlockCompiler.compile(text: text, maxRules: 35_000)
            subscriptions[idx].cachedRules = parsed.compiledRules
            subscriptions[idx].compiledRuleCount = parsed.compiledRules.count
            subscriptions[idx].rawLineCount = parsed.totalLines
            subscriptions[idx].lastUpdated = Date()
            subscriptions[idx].lastError = nil
            subscriptions[idx].isEnabled = true
            saveState()
            rebuildCompiledRules(syncSafari: true)
        } catch {
            subscriptions[idx].lastError = error.localizedDescription
            saveState()
        }
    }

    func updateAllEnabledSubscriptions() async {
        let targets = subscriptions.filter(\.isEnabled).map(\.id)
        for id in targets {
            await updateSubscription(id: id)
        }
    }

    func updateDNSConfig(_ transform: (inout DNSConfiguration) -> Void) {
        transform(&dnsConfig)
        saveState()
    }

    func rebuildCompiledRules(syncSafari: Bool) {
        var blockRules: [ContentBlockerRuleDTO] = []
        var exceptionRules: [ContentBlockerRuleDTO] = []

        if isMasterShieldEnabled {
            for cat in categories where cat.isEnabled {
                blockRules.append(contentsOf: cat.rules)
            }

            for sub in subscriptions where sub.isEnabled {
                for rule in sub.cachedRules {
                    if rule.action.type == "ignore-previous-rules" {
                        exceptionRules.append(rule)
                    } else {
                        blockRules.append(rule)
                    }
                }
            }

            let activeCustomText = customRules
                .filter(\.isEnabled)
                .map(\.rawText)
                .joined(separator: "\n")
            if !activeCustomText.isEmpty {
                let parsed = AdBlockCompiler.compile(text: activeCustomText, maxRules: 10_000)
                for rule in parsed.compiledRules {
                    if rule.action.type == "ignore-previous-rules" {
                        exceptionRules.append(rule)
                    } else {
                        blockRules.append(rule)
                    }
                }
            }

            if !allowlistDomains.isEmpty {
                let allowPatterns = allowlistDomains.map { "*\($0)" }
                exceptionRules.append(
                    ContentBlockerRuleDTO(
                        trigger: .init(urlFilter: ".*", ifDomain: allowPatterns),
                        action: .init(type: "ignore-previous-rules")
                    )
                )
            }
        }

        // Keep compiled count safely within Apple's 150,000 rule limit per blocker
        let maxBlockBudget = max(0, 145_000 - exceptionRules.count)
        let merged = Array(blockRules.prefix(maxBlockBudget)) + exceptionRules
        totalCompiledRuleCount = merged.count

        if merged.isEmpty {
            // WKContentRuleListStore rejects empty array []; pass harmless no-op fallback if paused
            compiledRuleListJSON = "[{\"trigger\":{\"url-filter\":\"^about:nullshield-noop$\"},\"action\":{\"type\":\"ignore-previous-rules\"}}]"
        } else if let json = try? AdBlockCompiler.encodeJSON(rules: merged) {
            compiledRuleListJSON = json
        }

        if syncSafari {
            Task {
                let elapsed = await safariService.syncAndReload(rules: merged)
                if elapsed > 0 {
                    stats.lastCompileDurationMs = elapsed
                    saveState()
                }
            }
        }
    }

    func forceSafariReload() {
        rebuildCompiledRules(syncSafari: true)
    }

    func recordBrowserBlocked(count: Int, kilobytesSaved: Int) {
        guard count > 0 else { return }
        stats.totalBrowserBlocked += count
        stats.estimatedKilobytesSaved += kilobytesSaved
        saveState()
    }

    func recordSanitizedLink() {
        stats.totalSanitizedLinks += 1
        saveState()
    }

    func recordXRayScan() {
        stats.totalXRayScans += 1
        saveState()
    }
}
