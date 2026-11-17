import Foundation

enum ShieldPreset: String, CaseIterable, Identifiable, Codable {
    case balanced
    case lockdown
    case reading
    case gaming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "平衡防護"
        case .lockdown: return "極限零噪"
        case .reading: return "純淨閱讀"
        case .gaming: return "遊戲免擾"
        }
    }

    var subtitle: String {
        switch self {
        case .balanced: return "Ads + 追蹤 + 區域廣告 + 安全"
        case .lockdown: return "全模組啟用・最嚴格阻擋"
        case .reading: return "強效清理蓋版、彈窗與 Cookie"
        case .gaming: return "專注全機 DNS 跨 App 攔截"
        }
    }

    var badgeText: String {
        switch self {
        case .balanced: return "日常推薦"
        case .lockdown: return "最高強度"
        case .reading: return "去蓋版"
        case .gaming: return "低耗電"
        }
    }

    var iconName: String {
        switch self {
        case .balanced: return "shield.lefthalf.filled"
        case .lockdown: return "bolt.shield.fill"
        case .reading: return "doc.text.magnifyingglass"
        case .gaming: return "gamecontroller.fill"
        }
    }

    var enabledCategoryIDs: Set<String> {
        switch self {
        case .balanced:
            return ["ads", "privacy", "annoyances", "regional", "security"]
        case .lockdown:
            return ["ads", "privacy", "annoyances", "social", "regional", "security"]
        case .reading:
            return ["ads", "annoyances", "regional", "security"]
        case .gaming:
            return ["ads", "privacy", "security"]
        }
    }
}

struct ContentBlockerRuleDTO: Codable, Hashable {
    struct Trigger: Codable, Hashable {
        let urlFilter: String
        let loadType: [String]?
        let resourceType: [String]?
        let ifDomain: [String]?
        let unlessDomain: [String]?

        enum CodingKeys: String, CodingKey {
            case urlFilter = "url-filter"
            case loadType = "load-type"
            case resourceType = "resource-type"
            case ifDomain = "if-domain"
            case unlessDomain = "unless-domain"
        }

        init(
            urlFilter: String,
            loadType: [String]? = nil,
            resourceType: [String]? = nil,
            ifDomain: [String]? = nil,
            unlessDomain: [String]? = nil
        ) {
            self.urlFilter = urlFilter
            self.loadType = loadType
            self.resourceType = resourceType
            self.ifDomain = ifDomain
            self.unlessDomain = unlessDomain
        }
    }

    struct Action: Codable, Hashable {
        let type: String
        let selector: String?

        init(type: String, selector: String? = nil) {
            self.type = type
            self.selector = selector
        }
    }

    let trigger: Trigger
    let action: Action
}

struct FilterPackCategoryDTO: Codable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let defaultEnabled: Bool
    let domains: [String]
    let rules: [ContentBlockerRuleDTO]
}

struct FilterPackPayloadDTO: Codable {
    let version: String
    let generatedAt: String
    let categories: [FilterPackCategoryDTO]
    let trackerIntel: [TrackerIntelEntry]
}

struct FilterCategoryState: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let domains: [String]
    let rules: [ContentBlockerRuleDTO]
    var isEnabled: Bool
}

struct FilterSubscription: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var urlString: String
    var categoryHint: String
    var isEnabled: Bool
    var compiledRuleCount: Int
    var rawLineCount: Int
    var lastUpdated: Date?
    var lastError: String?
    var cachedRules: [ContentBlockerRuleDTO]

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        categoryHint: String,
        isEnabled: Bool = false,
        compiledRuleCount: Int = 0,
        rawLineCount: Int = 0,
        lastUpdated: Date? = nil,
        lastError: String? = nil,
        cachedRules: [ContentBlockerRuleDTO] = []
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.categoryHint = categoryHint
        self.isEnabled = isEnabled
        self.compiledRuleCount = compiledRuleCount
        self.rawLineCount = rawLineCount
        self.lastUpdated = lastUpdated
        self.lastError = lastError
        self.cachedRules = cachedRules
    }
}

struct CustomFilterRule: Identifiable, Codable, Hashable {
    let id: UUID
    var rawText: String
    var isEnabled: Bool
    var note: String

    init(id: UUID = UUID(), rawText: String, isEnabled: Bool = true, note: String = "") {
        self.id = id
        self.rawText = rawText
        self.isEnabled = isEnabled
        self.note = note
    }
}

enum DNSProtocolMode: String, CaseIterable, Codable, Identifiable {
    case https = "HTTPS"
    case tls = "TLS"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .https: return "DNS-over-HTTPS (DoH)"
        case .tls: return "DNS-over-TLS (DoT)"
        }
    }
}

enum DNSNetworkScope: String, CaseIterable, Codable, Identifiable {
    case all = "all"
    case wifiOnly = "wifi"
    case cellularOnly = "cellular"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "全網路 (Wi-Fi + 行動)"
        case .wifiOnly: return "僅 Wi-Fi"
        case .cellularOnly: return "僅行動網路"
        }
    }
}

struct DNSProviderPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let badge: String
    let protocolMode: DNSProtocolMode
    let dohURL: String
    let dotHost: String
    let serverAddresses: [String]
    let supportsCustomProfileID: Bool
    let profilePlaceholder: String

    static let catalog: [DNSProviderPreset] = [
        DNSProviderPreset(
            id: "adguard-default",
            name: "AdGuard DNS",
            subtitle: "標準去廣告 + 追蹤防護 + 惡意網域攔截",
            badge: "推薦預設",
            protocolMode: .https,
            dohURL: "https://dns.adguard-dns.com/dns-query",
            dotHost: "dns.adguard-dns.com",
            serverAddresses: ["94.140.14.14", "94.140.15.15"],
            supportsCustomProfileID: false,
            profilePlaceholder: ""
        ),
        DNSProviderPreset(
            id: "adguard-family",
            name: "AdGuard Family",
            subtitle: "去廣告 + 成人內容過濾 + 安全搜尋",
            badge: "親子安全",
            protocolMode: .https,
            dohURL: "https://family.adguard-dns.com/dns-query",
            dotHost: "family.adguard-dns.com",
            serverAddresses: ["94.140.14.15", "94.140.15.16"],
            supportsCustomProfileID: false,
            profilePlaceholder: ""
        ),
        DNSProviderPreset(
            id: "mullvad-adblock",
            name: "Mullvad Adblock",
            subtitle: "瑞典嚴格零日誌・去廣告與追蹤過濾",
            badge: "極致隱私",
            protocolMode: .https,
            dohURL: "https://adblock.dns.mullvad.net/dns-query",
            dotHost: "adblock.dns.mullvad.net",
            serverAddresses: ["194.242.2.3"],
            supportsCustomProfileID: false,
            profilePlaceholder: ""
        ),
        DNSProviderPreset(
            id: "nextdns-custom",
            name: "NextDNS 自訂 ID",
            subtitle: "綁定你的 NextDNS 設定檔 ID，自訂規則與查詢紀錄",
            badge: "自訂雲端規則",
            protocolMode: .https,
            dohURL: "https://dns.nextdns.io/",
            dotHost: "dns.nextdns.io",
            serverAddresses: ["45.90.28.0", "45.90.30.0"],
            supportsCustomProfileID: true,
            profilePlaceholder: "輸入 6 碼 Profile ID（例如 a1b2c3）"
        ),
        DNSProviderPreset(
            id: "controld-custom",
            name: "Control D Free/Custom",
            subtitle: "支援 Hagezi / OISD 過濾或個人 Resolver ID",
            badge: "高彈性",
            protocolMode: .https,
            dohURL: "https://freedns.controld.com/",
            dotHost: "p2.freedns.controld.com",
            serverAddresses: ["76.76.2.2", "76.76.10.2"],
            supportsCustomProfileID: true,
            profilePlaceholder: "留空預設 p2（去廣告+追蹤）或輸入 Resolver ID"
        ),
        DNSProviderPreset(
            id: "quad9-security",
            name: "Quad9 Security",
            subtitle: "專注威脅情報、惡意軟體與釣魚網站阻擋",
            badge: "防釣魚",
            protocolMode: .https,
            dohURL: "https://dns.quad9.net/dns-query",
            dotHost: "dns.quad9.net",
            serverAddresses: ["9.9.9.9", "149.112.112.112"],
            supportsCustomProfileID: false,
            profilePlaceholder: ""
        ),
        DNSProviderPreset(
            id: "custom-endpoint",
            name: "完全自訂 DoH / DoT",
            subtitle: "手動填寫自架 AdGuard Home / Pi-hole / 私人加密端點",
            badge: "進階自訂",
            protocolMode: .https,
            dohURL: "",
            dotHost: "",
            serverAddresses: [],
            supportsCustomProfileID: false,
            profilePlaceholder: ""
        )
    ]
}

struct DNSConfiguration: Codable, Equatable {
    var selectedProviderID: String = "adguard-default"
    var customProfileID: String = ""
    var customProtocolMode: DNSProtocolMode = .https
    var customDoHURL: String = "https://dns.adguard-dns.com/dns-query"
    var customDoTHost: String = "dns.adguard-dns.com"
    var customIPsText: String = "94.140.14.14, 94.140.15.15"
    var networkScope: DNSNetworkScope = .all
    var excludedSSIDsText: String = ""

    var activePreset: DNSProviderPreset {
        DNSProviderPreset.catalog.first(where: { $0.id == selectedProviderID }) ?? DNSProviderPreset.catalog[0]
    }

    var resolvedProtocol: DNSProtocolMode {
        if selectedProviderID == "custom-endpoint" {
            return customProtocolMode
        }
        return activePreset.protocolMode
    }

    var resolvedDoHURL: String {
        let trimmedID = customProfileID.trimmingCharacters(in: .whitespacesAndNewlines)
        switch selectedProviderID {
        case "nextdns-custom":
            return trimmedID.isEmpty ? "https://dns.nextdns.io" : "https://dns.nextdns.io/\(trimmedID)"
        case "controld-custom":
            return trimmedID.isEmpty ? "https://freedns.controld.com/p2" : "https://freedns.controld.com/\(trimmedID)"
        case "custom-endpoint":
            return customDoHURL.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return activePreset.dohURL
        }
    }

    var resolvedDoTHost: String {
        let trimmedID = customProfileID.trimmingCharacters(in: .whitespacesAndNewlines)
        switch selectedProviderID {
        case "nextdns-custom":
            return trimmedID.isEmpty ? "dns.nextdns.io" : "\(trimmedID).dns.nextdns.io"
        case "controld-custom":
            return trimmedID.isEmpty ? "p2.freedns.controld.com" : "\(trimmedID).freedns.controld.com"
        case "custom-endpoint":
            return customDoTHost.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return activePreset.dotHost
        }
    }

    var resolvedServerAddresses: [String] {
        if selectedProviderID == "custom-endpoint" {
            return customIPsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return activePreset.serverAddresses
    }

    var excludedSSIDs: [String] {
        excludedSSIDsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct TelemetryStats: Codable {
    var totalBrowserBlocked: Int = 0
    var totalSanitizedLinks: Int = 0
    var totalXRayScans: Int = 0
    var estimatedKilobytesSaved: Int = 0
    var lastCompileDurationMs: Int = 0

    var estimatedSavedLabel: String {
        if estimatedKilobytesSaved >= 1024 {
            return String(format: "%.1f MB", Double(estimatedKilobytesSaved) / 1024.0)
        }
        return "\(estimatedKilobytesSaved) KB"
    }
}
