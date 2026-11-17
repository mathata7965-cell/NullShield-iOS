import Foundation
import SafariServices

@MainActor
final class SafariBlockerService: ObservableObject {
    @Published private(set) var hasEmbeddedExtension: Bool = false
    @Published private(set) var extensionBundleID: String?
    @Published private(set) var isExtensionEnabled: Bool?
    @Published private(set) var appGroupSyncActive: Bool = false
    @Published private(set) var isReloading: Bool = false
    @Published private(set) var lastReloadDate: Date?
    @Published private(set) var lastStatusMessage: String = "尚未檢查 Safari 延伸功能狀態"

    init() {
        discoverEmbeddedExtension()
    }

    func discoverEmbeddedExtension() {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: pluginsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            hasEmbeddedExtension = false
            extensionBundleID = nil
            return
        }

        for item in contents where item.pathExtension == "appex" {
            if let extBundle = Bundle(url: item),
               let info = extBundle.infoDictionary,
               let extDict = info["NSExtension"] as? [String: Any],
               let point = extDict["NSExtensionPointIdentifier"] as? String,
               point == "com.apple.Safari.content-blocker",
               let bundleID = extBundle.bundleIdentifier {
                hasEmbeddedExtension = true
                extensionBundleID = bundleID
                checkAppGroupAvailability()
                return
            }
        }

        hasEmbeddedExtension = false
        extensionBundleID = nil
    }

    private func sharedGroupContainerURL() -> URL? {
        guard let mainID = Bundle.main.bundleIdentifier else { return nil }
        let groupID = "group.\(mainID)"
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    private func checkAppGroupAvailability() {
        appGroupSyncActive = (sharedGroupContainerURL() != nil)
    }

    func refreshStatus() async {
        discoverEmbeddedExtension()
        guard let bundleID = extensionBundleID else {
            isExtensionEnabled = nil
            lastStatusMessage = "目前安裝的是單一 App ID 免延伸版本，Safari 外掛不可用（可改裝完整版 IPA 或使用內建安全瀏覽器與全機 DNS 盾）。"
            return
        }

        do {
            let enabled: Bool = try await withCheckedThrowingContinuation { continuation in
                SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: bundleID) { state, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: state?.isEnabled ?? false)
                    }
                }
            }
            isExtensionEnabled = enabled
            if enabled {
                lastStatusMessage = "Safari 內容阻擋器已啟用並保護 Safari 瀏覽中"
            } else {
                lastStatusMessage = "尚未於 iPhone「設定 → Safari → 延伸功能」開啟「Null Safari 盾」"
            }
        } catch {
            isExtensionEnabled = false
            lastStatusMessage = "無法讀取 Safari 狀態：\(error.localizedDescription)"
        }
    }

    func syncAndReload(rules: [ContentBlockerRuleDTO]) async -> Int {
        discoverEmbeddedExtension()
        guard let bundleID = extensionBundleID else {
            lastStatusMessage = "單一 App ID 版本不含 Safari 外掛，規則已直接套用至內建安全瀏覽器。"
            return 0
        }

        isReloading = true
        defer { isReloading = false }
        let start = CFAbsoluteTimeGetCurrent()

        if let groupURL = sharedGroupContainerURL() {
            appGroupSyncActive = true
            let fileURL = groupURL.appendingPathComponent("blockerList.json")
            if let json = try? AdBlockCompiler.encodeJSON(rules: rules) {
                try? json.data(using: .utf8)?.write(to: fileURL, options: .atomic)
            }
        } else {
            appGroupSyncActive = false
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                SFContentBlockerManager.reloadContentBlocker(withIdentifier: bundleID) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000.0)
            lastReloadDate = Date()
            await refreshStatus()
            if appGroupSyncActive {
                lastStatusMessage = "已同步自訂與訂閱規則至 Safari（耗時 \(elapsedMs) ms）"
            } else {
                lastStatusMessage = "Safari 內建規則庫已重新載入（\(elapsedMs) ms）；免付費簽章環境下自訂規則會即時於內建瀏覽器生效。"
            }
            return elapsedMs
        } catch {
            lastStatusMessage = "Safari 規則載入失敗：\(error.localizedDescription)"
            return 0
        }
    }
}
