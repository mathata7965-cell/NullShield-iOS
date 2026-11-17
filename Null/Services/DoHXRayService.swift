import Foundation

enum DoHXRayService {
    private struct DoHJSONResponse: Decodable {
        struct Answer: Decodable {
            let name: String?
            let type: Int
            let TTL: Int?
            let data: String
        }

        let Status: Int
        let Answer: [Answer]?
    }

    static func scanDomain(
        _ rawDomain: String,
        categories: [FilterCategoryState],
        customRules: [CustomFilterRule],
        intelCatalog: [TrackerIntelEntry]
    ) async -> XRayScanResult {
        let domain = normalizeDomain(rawDomain)

        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain
        async let standardTask = queryDoH(
            domain: domain,
            endpoint: "https://cloudflare-dns.com/dns-query?name=\(encodedDomain)&type=A",
            providerName: "Cloudflare 標準解析"
        )
        async let filteredTask = queryDoH(
            domain: domain,
            endpoint: "https://dns.adguard-dns.com/resolve?name=\(encodedDomain)&type=A",
            providerName: "AdGuard 過濾盾解析"
        )

        let standardProbe = await standardTask
        let filteredProbe = await filteredTask

        let matchedCategories = categories
            .filter { cat in
                cat.domains.contains(where: { domain == $0 || domain.hasSuffix(".\($0)") })
            }
            .map(\.name)

        let matchedCustom = customRules.first { rule in
            rule.isEnabled && rule.rawText.lowercased().contains(domain)
        }?.rawText

        let directIntel = findIntel(for: domain, catalog: intelCatalog)

        var cnameVendor: TrackerIntelEntry? = nil
        for cname in standardProbe.cnameChain {
            if let hit = findIntel(for: cname, catalog: intelCatalog) {
                cnameVendor = hit
                break
            }
        }

        return XRayScanResult(
            queryDomain: domain,
            scannedAt: Date(),
            standardProbe: standardProbe,
            filteredProbe: filteredProbe,
            matchedLocalCategories: matchedCategories,
            matchedCustomRule: matchedCustom,
            matchedIntel: directIntel,
            cnameCloakingVendor: cnameVendor
        )
    }

    private static func findIntel(for host: String, catalog: [TrackerIntelEntry]) -> TrackerIntelEntry? {
        let clean = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return catalog.first { entry in
            clean == entry.domain || clean.hasSuffix(".\(entry.domain)")
        }
    }

    private static func queryDoH(domain: String, endpoint: String, providerName: String) async -> DNSProbeOutcome {
        guard let url = URL(string: endpoint) else {
            return DNSProbeOutcome(
                providerName: providerName,
                latencyMs: 0,
                status: -1,
                answers: [],
                cnameChain: [],
                isBlockedByDNS: false,
                errorMessage: "無效的查詢網址"
            )
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let latencyMs = max(1, Int((CFAbsoluteTimeGetCurrent() - start) * 1000.0))
            let decoded = try JSONDecoder().decode(DoHJSONResponse.self, from: data)

            let records: [DNSAnswerRecord] = (decoded.Answer ?? []).map { ans in
                DNSAnswerRecord(
                    name: ans.name ?? domain,
                    typeCode: ans.type,
                    typeName: dnsTypeName(ans.type),
                    ttl: ans.TTL ?? 0,
                    data: ans.data
                )
            }

            let cnames = records
                .filter { $0.typeCode == 5 }
                .map { $0.data.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() }

            let hasNullIP = records.contains { rec in
                rec.typeCode == 1 && (rec.data == "0.0.0.0" || rec.data == "127.0.0.1")
            }
            let hasNullAAAA = records.contains { rec in
                rec.typeCode == 28 && (rec.data == "::" || rec.data == "::1")
            }
            let isNXOrRefused = decoded.Status == 3 || decoded.Status == 5
            let emptyBlocked = (decoded.Status == 0 && records.isEmpty)

            return DNSProbeOutcome(
                providerName: providerName,
                latencyMs: latencyMs,
                status: decoded.Status,
                answers: records,
                cnameChain: cnames,
                isBlockedByDNS: hasNullIP || hasNullAAAA || isNXOrRefused || emptyBlocked,
                errorMessage: nil
            )
        } catch {
            let latencyMs = max(1, Int((CFAbsoluteTimeGetCurrent() - start) * 1000.0))
            return DNSProbeOutcome(
                providerName: providerName,
                latencyMs: latencyMs,
                status: -1,
                answers: [],
                cnameChain: [],
                isBlockedByDNS: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    static func normalizeDomain(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let url = URL(string: s), let host = url.host {
            s = host
        } else {
            s = s.replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            if let slashIdx = s.firstIndex(of: "/") {
                s = String(s[..<slashIdx])
            }
            if let colonIdx = s.firstIndex(of: ":") {
                s = String(s[..<colonIdx])
            }
        }
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func dnsTypeName(_ code: Int) -> String {
        switch code {
        case 1: return "A"
        case 5: return "CNAME"
        case 16: return "TXT"
        case 28: return "AAAA"
        default: return "TYPE\(code)"
        }
    }
}
