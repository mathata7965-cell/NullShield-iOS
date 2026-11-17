import Foundation

struct TrackerIntelEntry: Codable, Identifiable, Hashable {
    var id: String { domain }
    let domain: String
    let vendor: String
    let category: String
    let risk: String
    let summary: String
}

struct DNSAnswerRecord: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let typeCode: Int
    let typeName: String
    let ttl: Int
    let data: String
}

struct DNSProbeOutcome: Hashable {
    let providerName: String
    let latencyMs: Int
    let status: Int
    let answers: [DNSAnswerRecord]
    let cnameChain: [String]
    let isBlockedByDNS: Bool
    let errorMessage: String?
}

struct XRayScanResult: Identifiable {
    let id = UUID()
    let queryDomain: String
    let scannedAt: Date
    let standardProbe: DNSProbeOutcome
    let filteredProbe: DNSProbeOutcome
    let matchedLocalCategories: [String]
    let matchedCustomRule: String?
    let matchedIntel: TrackerIntelEntry?
    let cnameCloakingVendor: TrackerIntelEntry?

    var isProtectedLocally: Bool {
        !matchedLocalCategories.isEmpty || matchedCustomRule != nil
    }

    var isProtectedByDNS: Bool {
        filteredProbe.isBlockedByDNS
    }
}

struct StrippedQueryParam: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let value: String
    let reason: String
}

struct LinkSanitizeResult {
    let originalURL: String
    let cleanedURL: String
    let strippedParams: [StrippedQueryParam]
    let isValid: Bool
}
