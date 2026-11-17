import Foundation

enum AdBlockCompiler {
    struct ParseStats {
        let compiledRules: [ContentBlockerRuleDTO]
        let totalLines: Int
        let skippedLines: Int
    }

    private static let resourceTypeMap: [String: String] = [
        "script": "script",
        "image": "image",
        "img": "image",
        "stylesheet": "style-sheet",
        "css": "style-sheet",
        "xmlhttprequest": "raw",
        "xhr": "raw",
        "fetch": "raw",
        "subdocument": "document",
        "document": "document",
        "font": "font",
        "media": "media",
        "popup": "popup"
    ]

    static func compile(text: String, maxRules: Int = 50_000) -> ParseStats {
        let lines = text.split(whereSeparator: \.isNewline)
        var blockRules: [ContentBlockerRuleDTO] = []
        var exceptionRules: [ContentBlockerRuleDTO] = []
        var skipped = 0

        for rawSub in lines {
            if blockRules.count + exceptionRules.count >= maxRules {
                break
            }
            let line = rawSub.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("!") || line.hasPrefix("[") || line.hasPrefix("# ") {
                continue
            }

            if let rule = parseSingleLine(line) {
                if rule.action.type == "ignore-previous-rules" {
                    exceptionRules.append(rule)
                } else {
                    blockRules.append(rule)
                }
            } else {
                skipped += 1
            }
        }

        // WebKit Content Blocker requires ignore-previous-rules after block rules to override them.
        return ParseStats(
            compiledRules: blockRules + exceptionRules,
            totalLines: lines.count,
            skippedLines: skipped
        )
    }

    static func parseSingleLine(_ rawLine: String) -> ContentBlockerRuleDTO? {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        // 1. Element hiding: domain1,domain2##selector or ##selector (skip exception #@# and extended #?#)
        if line.contains("#@#") || line.contains("#?#") || line.contains("#$#") {
            return nil
        }
        if let range = line.range(of: "##") {
            let domainsPart = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let selector = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !selector.isEmpty, selector.allSatisfy({ $0.isASCII }) else { return nil }

            if domainsPart.isEmpty {
                return ContentBlockerRuleDTO(
                    trigger: .init(urlFilter: ".*"),
                    action: .init(type: "css-display-none", selector: selector)
                )
            }

            let rawDomains = domainsPart.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
            let positives = rawDomains.filter { !$0.hasPrefix("~") && isValidDomainPattern($0) }.map { "*\($0)" }
            let negatives = rawDomains.filter { $0.hasPrefix("~") }.map { String($0.dropFirst()) }.filter { isValidDomainPattern($0) }.map { "*\($0)" }

            if !positives.isEmpty && negatives.isEmpty {
                return ContentBlockerRuleDTO(
                    trigger: .init(urlFilter: ".*", ifDomain: positives),
                    action: .init(type: "css-display-none", selector: selector)
                )
            } else if positives.isEmpty && !negatives.isEmpty {
                return ContentBlockerRuleDTO(
                    trigger: .init(urlFilter: ".*", unlessDomain: negatives),
                    action: .init(type: "css-display-none", selector: selector)
                )
            }
            return nil
        }

        // 2. Hosts line: "0.0.0.0 example.com" or "127.0.0.1 example.com"
        if line.hasPrefix("0.0.0.0 ") || line.hasPrefix("127.0.0.1 ") || line.hasPrefix("0.0.0.0\t") || line.hasPrefix("127.0.0.1\t") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 2 {
                var host = String(parts[1]).lowercased()
                if let hashIdx = host.firstIndex(of: "#") {
                    host = String(host[..<hashIdx])
                }
                guard host != "localhost", host != "0.0.0.0", isValidDomainPattern(host) else { return nil }
                return makeDomainRule(domain: host, isException: false, loadType: nil, resourceTypes: nil, ifDomains: nil, unlessDomains: nil)
            }
            return nil
        }

        // 3. Network rule (optionally starting with @@)
        var working = line
        var isException = false
        if working.hasPrefix("@@") {
            isException = true
            working = String(working.dropFirst(2))
        }

        var patternPart = working
        var optionsPart = ""
        if let dollarIdx = working.lastIndex(of: "$") {
            let candidateOpts = String(working[working.index(after: dollarIdx)...])
            if !candidateOpts.contains("/") {
                patternPart = String(working[..<dollarIdx])
                optionsPart = candidateOpts
            }
        }

        var loadType: [String]? = nil
        var resourceTypes: [String] = []
        var ifDomains: [String] = []
        var unlessDomains: [String] = []

        if !optionsPart.isEmpty {
            let tokens = optionsPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            for tok in tokens {
                if tok == "third-party" || tok == "3p" {
                    loadType = ["third-party"]
                } else if tok == "~third-party" || tok == "1p" || tok == "first-party" {
                    loadType = ["first-party"]
                } else if let mapped = resourceTypeMap[tok] {
                    if !resourceTypes.contains(mapped) {
                        resourceTypes.append(mapped)
                    }
                } else if tok.hasPrefix("domain=") {
                    let domList = tok.dropFirst("domain=".count).split(separator: "|")
                    for rawD in domList {
                        let d = String(rawD)
                        if d.hasPrefix("~") {
                            let clean = String(d.dropFirst())
                            if isValidDomainPattern(clean) { unlessDomains.append("*\(clean)") }
                        } else if isValidDomainPattern(d) {
                            ifDomains.append("*\(d)")
                        }
                    }
                } else if tok == "important" || tok == "all" {
                    continue
                } else if tok.hasPrefix("removeparam") || tok.hasPrefix("csp") || tok.hasPrefix("redirect") || tok.hasPrefix("replace") || tok.hasPrefix("badfilter") {
                    return nil
                }
            }
        }

        // Cannot combine if-domain and unless-domain in one WebKit rule
        if !ifDomains.isEmpty && !unlessDomains.isEmpty {
            unlessDomains.removeAll()
        }

        // Pure domain pattern: ||example.com^ or bare domain
        if patternPart.hasPrefix("||") {
            var body = String(patternPart.dropFirst(2))
            if body.hasSuffix("^") {
                body = String(body.dropLast())
            }
            if !body.contains("/") && !body.contains("*") && isValidDomainPattern(body) {
                return makeDomainRule(
                    domain: body.lowercased(),
                    isException: isException,
                    loadType: loadType,
                    resourceTypes: resourceTypes.isEmpty ? nil : resourceTypes,
                    ifDomains: ifDomains.isEmpty ? nil : ifDomains,
                    unlessDomains: unlessDomains.isEmpty ? nil : unlessDomains
                )
            }
            // Domain + path: ||example.com/ads/*
            let regex = convertAdblockPatternToRegex(body, anchoredAtDomain: true)
            guard let validRegex = regex else { return nil }
            return ContentBlockerRuleDTO(
                trigger: .init(
                    urlFilter: validRegex,
                    loadType: loadType,
                    resourceType: resourceTypes.isEmpty ? nil : resourceTypes,
                    ifDomain: ifDomains.isEmpty ? nil : ifDomains,
                    unlessDomain: unlessDomains.isEmpty ? nil : unlessDomains
                ),
                action: .init(type: isException ? "ignore-previous-rules" : "block")
            )
        }

        // Bare domain like "ads.example.com"
        if !patternPart.contains("/") && !patternPart.contains("*") && !patternPart.contains("^") && isValidDomainPattern(patternPart) {
            return makeDomainRule(
                domain: patternPart.lowercased(),
                isException: isException,
                loadType: loadType,
                resourceTypes: resourceTypes.isEmpty ? nil : resourceTypes,
                ifDomains: ifDomains.isEmpty ? nil : ifDomains,
                unlessDomains: unlessDomains.isEmpty ? nil : unlessDomains
            )
        }

        // Generic wildcard rule (ignore regex-literal /.../ for strict WebKit DFA safety unless valid ASCII)
        guard let regex = convertAdblockPatternToRegex(patternPart, anchoredAtDomain: false) else {
            return nil
        }

        return ContentBlockerRuleDTO(
            trigger: .init(
                urlFilter: regex,
                loadType: loadType,
                resourceType: resourceTypes.isEmpty ? nil : resourceTypes,
                ifDomain: ifDomains.isEmpty ? nil : ifDomains,
                unlessDomain: unlessDomains.isEmpty ? nil : unlessDomains
            ),
            action: .init(type: isException ? "ignore-previous-rules" : "block")
        )
    }

    static func makeDomainRule(
        domain: String,
        isException: Bool,
        loadType: [String]?,
        resourceTypes: [String]?,
        ifDomains: [String]?,
        unlessDomains: [String]?
    ) -> ContentBlockerRuleDTO {
        let escaped = escapeRegex(domain)
        return ContentBlockerRuleDTO(
            trigger: .init(
                urlFilter: "^https?://([a-z0-9-]+\\.)*\(escaped)[:/?]",
                loadType: loadType,
                resourceType: resourceTypes,
                ifDomain: ifDomains,
                unlessDomain: unlessDomains
            ),
            action: .init(type: isException ? "ignore-previous-rules" : "block")
        )
    }

    private static func convertAdblockPatternToRegex(_ pattern: String, anchoredAtDomain: Bool) -> String? {
        guard !pattern.isEmpty, pattern.allSatisfy({ $0.isASCII }) else { return nil }
        if pattern.hasPrefix("/") && pattern.hasSuffix("/") && pattern.count > 2 {
            return nil
        }

        var working = pattern
        var prefix = ""
        if anchoredAtDomain {
            prefix = "^https?://([a-z0-9-]+\\.)*"
        } else if working.hasPrefix("|") {
            working = String(working.dropFirst())
            prefix = "^"
        }

        var suffix = ""
        if working.hasSuffix("|") {
            working = String(working.dropLast())
            suffix = "$"
        }

        var out = prefix
        for ch in working {
            switch ch {
            case "*":
                out += ".*"
            case "^":
                out += "[:/?#&]"
            case ".", "+", "?", "(", ")", "[", "]", "{", "}", "\\", "$", "|":
                out += "\\" + String(ch)
            default:
                out.append(ch)
            }
        }
        out += suffix

        guard out.count >= 4, !out.contains(".*.*") else {
            return out.replacingOccurrences(of: ".*.*", with: ".*")
        }
        return out
    }

    private static func escapeRegex(_ raw: String) -> String {
        let special = CharacterSet(charactersIn: ".+*?^${}()|[]\\")
        var result = ""
        for scalar in raw.unicodeScalars {
            if special.contains(scalar) {
                result.append("\\")
            }
            result.append(Character(scalar))
        }
        return result
    }

    static func isValidDomainPattern(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.contains("."), !trimmed.contains(" "), trimmed.allSatisfy({ $0.isASCII }) else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) } && !trimmed.hasPrefix(".") && !trimmed.hasSuffix(".")
    }

    static func encodeJSON(rules: [ContentBlockerRuleDTO]) throws -> String {
        let capped = Array(rules.prefix(145_000))
        let encoder = JSONEncoder()
        let data = try encoder.encode(capped)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
