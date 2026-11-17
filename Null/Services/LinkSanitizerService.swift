import Foundation

enum LinkSanitizerService {
    private static let trackerKeys: [String: String] = [
        "utm_source": "行銷流量來源標籤",
        "utm_medium": "行銷媒介標籤",
        "utm_campaign": "廣告活動名稱",
        "utm_term": "關鍵字追蹤參數",
        "utm_content": "A/B 測試素材版本",
        "utm_id": "GA 活動識別碼",
        "utm_name": "活動別名追蹤",
        "fbclid": "Meta / Facebook 點擊追蹤碼",
        "gclid": "Google Ads 點擊歸因碼",
        "gclsrc": "Google Ads 來源追蹤碼",
        "gbraid": "Google iOS 隱私歸因參數",
        "wbraid": "Google 網頁轉 App 歸因碼",
        "dclid": "DoubleClick 顯示廣告點擊碼",
        "msclkid": "Microsoft Bing 廣告點擊碼",
        "ttclid": "TikTok 廣告點擊歸因碼",
        "twclid": "X / Twitter 廣告點擊碼",
        "li_fat_id": "LinkedIn 廣告追蹤 ID",
        "igshid": "Instagram 分享者裝置指紋",
        "igsh": "Instagram 分享追蹤識別碼",
        "si": "YouTube / Spotify 分享追蹤碼",
        "pp": "YouTube 推廣追蹤參數",
        "feature": "YouTube 導流來源標籤",
        "spm": "阿里 / 淘寶頁面路徑追蹤碼",
        "scm": "演算法推薦點擊追蹤碼",
        "pvid": "電商頁面瀏覽唯一 ID",
        "algo_pvid": "演算法曝光識別碼",
        "algo_expid": "電商 A/B 實驗歸因碼",
        "mc_cid": "Mailchimp 電子報活動 ID",
        "mc_eid": "Mailchimp 收件人加密追蹤 ID",
        "yclid": "Yandex 廣告點擊追蹤碼",
        "_ga": "Google Analytics 跨網域訪客 ID",
        "_gl": "Google Tag 跨站連結追蹤器",
        "ref": "推薦來源追蹤參數",
        "ref_src": "社群引薦來源追蹤",
        "ref_url": "引薦來源網址",
        "mibextid": "Meta 行動分享帳號追蹤碼",
        "__tn__": "Facebook 版位追蹤結構碼",
        "__cft__": "Facebook 動態牆內容追蹤陣列",
        "share_id": "App 內建分享者識別 ID",
        "share_token": "跨 App 分享追蹤權杖",
        "openExternalBrowser": "App 跳轉追蹤標記",
        "s_kwcid": "Adobe Analytics 關鍵字 ID",
        "icid": "站內促銷追蹤碼",
        "oly_anon_id": "Omeda 匿名讀者追蹤 ID",
        "oly_enc_id": "Omeda 讀者加密識別碼",
        "vero_id": "Vero 郵件自動化追蹤 ID",
        "hsCtaTracking": "HubSpot CTA 點擊追蹤",
        "_hsenc": "HubSpot 加密聯絡人識別碼",
        "_hsmi": "HubSpot 郵件活動 ID"
    ]

    static func sanitize(_ rawInput: String) -> LinkSanitizeResult {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LinkSanitizeResult(originalURL: rawInput, cleanedURL: "", strippedParams: [], isValid: false)
        }

        let normalizedInput: String
        if trimmed.contains("://") {
            normalizedInput = trimmed
        } else if trimmed.contains(".") {
            normalizedInput = "https://\(trimmed)"
        } else {
            return LinkSanitizeResult(originalURL: rawInput, cleanedURL: rawInput, strippedParams: [], isValid: false)
        }

        guard var components = URLComponents(string: normalizedInput), components.host != nil else {
            return LinkSanitizeResult(originalURL: rawInput, cleanedURL: rawInput, strippedParams: [], isValid: false)
        }

        var stripped: [StrippedQueryParam] = []
        if let items = components.queryItems, !items.isEmpty {
            var kept: [URLQueryItem] = []
            for item in items {
                let lower = item.name.lowercased()
                if let reason = matchTrackerReason(for: lower) {
                    stripped.append(
                        StrippedQueryParam(
                            key: item.name,
                            value: item.value ?? "",
                            reason: reason
                        )
                    )
                } else {
                    kept.append(item)
                }
            }
            components.queryItems = kept.isEmpty ? nil : kept
        }

        let cleaned = components.string ?? normalizedInput
        return LinkSanitizeResult(
            originalURL: trimmed,
            cleanedURL: cleaned,
            strippedParams: stripped,
            isValid: true
        )
    }

    private static func matchTrackerReason(for lowerKey: String) -> String? {
        if let exact = trackerKeys[lowerKey] {
            return exact
        }
        if lowerKey.hasPrefix("utm_") {
            return "UTM 行銷追蹤參數"
        }
        if lowerKey.hasPrefix("__cft__") {
            return "Facebook 動態追蹤碼"
        }
        if lowerKey.hasPrefix("pk_") || lowerKey.hasPrefix("mtm_") {
            return "Matomo / Piwik 統計參數"
        }
        return nil
    }
}
