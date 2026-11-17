import Foundation
import Network
import NetworkExtension
import UIKit

@MainActor
final class DNSProfileService: ObservableObject {
    @Published private(set) var directExtensionStatus: String = "未套用系統直連設定"
    @Published private(set) var isDirectExtensionEnabled: Bool = false
    @Published private(set) var isWorking: Bool = false
    @Published private(set) var profileInstallMessage: String?

    private var listener: NWListener?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func buildMobileConfigXML(for config: DNSConfiguration) -> String {
        let profileUUID = UUID().uuidString.uppercased()
        let dnsPayloadUUID = UUID().uuidString.uppercased()
        let providerName = xmlEscape(config.activePreset.name)

        var dnsSettingsLines: [String] = []
        switch config.resolvedProtocol {
        case .https:
            dnsSettingsLines.append("\t\t\t\t<key>DNSProtocol</key>")
            dnsSettingsLines.append("\t\t\t\t<string>HTTPS</string>")
            dnsSettingsLines.append("\t\t\t\t<key>ServerURL</key>")
            dnsSettingsLines.append("\t\t\t\t<string>\(xmlEscape(config.resolvedDoHURL))</string>")
        case .tls:
            dnsSettingsLines.append("\t\t\t\t<key>DNSProtocol</key>")
            dnsSettingsLines.append("\t\t\t\t<string>TLS</string>")
            dnsSettingsLines.append("\t\t\t\t<key>ServerName</key>")
            dnsSettingsLines.append("\t\t\t\t<string>\(xmlEscape(config.resolvedDoTHost))</string>")
        }

        let ips = config.resolvedServerAddresses
        if !ips.isEmpty {
            dnsSettingsLines.append("\t\t\t\t<key>ServerAddresses</key>")
            dnsSettingsLines.append("\t\t\t\t<array>")
            for ip in ips {
                dnsSettingsLines.append("\t\t\t\t\t<string>\(xmlEscape(ip))</string>")
            }
            dnsSettingsLines.append("\t\t\t\t</array>")
        }

        var onDemandRulesXML = ""
        var ruleBlocks: [String] = []

        if !config.excludedSSIDs.isEmpty {
            let ssidItems = config.excludedSSIDs
                .map { "\t\t\t\t\t\t<string>\(xmlEscape($0))</string>" }
                .joined(separator: "\n")
            ruleBlocks.append("""
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Action</key>
            \t\t\t\t\t<string>Disconnect</string>
            \t\t\t\t\t<key>SSIDMatch</key>
            \t\t\t\t\t<array>
            \(ssidItems)
            \t\t\t\t\t</array>
            \t\t\t\t</dict>
            """)
        }

        switch config.networkScope {
        case .all:
            ruleBlocks.append("""
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Action</key>
            \t\t\t\t\t<string>Connect</string>
            \t\t\t\t</dict>
            """)
        case .wifiOnly:
            ruleBlocks.append("""
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Action</key>
            \t\t\t\t\t<string>Connect</string>
            \t\t\t\t\t<key>InterfaceTypeMatch</key>
            \t\t\t\t\t<string>WiFi</string>
            \t\t\t\t</dict>
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Action</key>
            \t\t\t\t\t<string>Disconnect</string>
            \t\t\t\t</dict>
            """)
        case .cellularOnly:
            ruleBlocks.append("""
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Action</key>
            \t\t\t\t\t<string>Connect</string>
            \t\t\t\t\t<key>InterfaceTypeMatch</key>
            \t\t\t\t\t<string>Cellular</string>
            \t\t\t\t</dict>
            \t\t\t\t<dict>
            \t\t\t\t\t<key>Action</key>
            \t\t\t\t\t<string>Disconnect</string>
            \t\t\t\t</dict>
            """)
        }

        if !ruleBlocks.isEmpty {
            onDemandRulesXML = """
            \n\t\t\t<key>OnDemandRules</key>
            \t\t\t<array>
            \(ruleBlocks.joined(separator: "\n"))
            \t\t\t</array>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>PayloadContent</key>
        \t<array>
        \t\t<dict>
        \t\t\t<key>DNSSettings</key>
        \t\t\t<dict>
        \(dnsSettingsLines.joined(separator: "\n"))
        \t\t\t</dict>\(onDemandRulesXML)
        \t\t\t<key>PayloadDescription</key>
        \t\t\t<string>Null 零噪盾全機加密 DNS 過濾設定（跨 App 阻擋廣告與追蹤）</string>
        \t\t\t<key>PayloadDisplayName</key>
        \t\t\t<string>Null DNS · \(providerName)</string>
        \t\t\t<key>PayloadIdentifier</key>
        \t\t\t<string>com.nullshield.dns.\(dnsPayloadUUID)</string>
        \t\t\t<key>PayloadType</key>
        \t\t\t<string>com.apple.dnsSettings.managed</string>
        \t\t\t<key>PayloadUUID</key>
        \t\t\t<string>\(dnsPayloadUUID)</string>
        \t\t\t<key>PayloadVersion</key>
        \t\t\t<integer>1</integer>
        \t\t\t<key>ProhibitDisablement</key>
        \t\t\t<false/>
        \t\t</dict>
        \t</array>
        \t<key>PayloadDescription</key>
        \t<string>透過 iOS 原生加密 DNS 協定提供全機跨 App 去廣告與隱私防護。</string>
        \t<key>PayloadDisplayName</key>
        \t<string>Null 全機加密 DNS 盾 (\(providerName))</string>
        \t<key>PayloadIdentifier</key>
        \t<string>com.nullshield.profile.\(profileUUID)</string>
        \t<key>PayloadRemovalDisallowed</key>
        \t<false/>
        \t<key>PayloadType</key>
        \t<string>Configuration</string>
        \t<key>PayloadUUID</key>
        \t<string>\(profileUUID)</string>
        \t<key>PayloadVersion</key>
        \t<integer>1</integer>
        </dict>
        </plist>
        """
    }

    func exportMobileConfigURL(for config: DNSConfiguration) -> URL? {
        let xml = buildMobileConfigXML(for: config)
        guard let data = xml.data(using: .utf8) else { return nil }
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Null-DNS-Shield.mobileconfig")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    func launchOneTapProfileInstaller(for config: DNSConfiguration) {
        let xml = buildMobileConfigXML(for: config)
        guard let data = xml.data(using: .utf8) else {
            profileInstallMessage = "產生描述檔資料失敗"
            return
        }

        stopLocalServer()

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "NullMobileConfigServer") { [weak self] in
            Task { @MainActor in
                self?.stopLocalServer()
            }
        }

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        if let port = self.listener?.port?.rawValue,
                           let url = URL(string: "http://127.0.0.1:\(port)/null-dns.mobileconfig") {
                            self.profileInstallMessage = "已啟動本機描述檔通道（Port \(port)），請在 Safari 點選「允許」下載，再前往「設定 → 一般 → VPN 與裝置管理」完成安裝。"
                            _ = await UIApplication.shared.open(url)
                        }
                    case .failed(let error):
                        self.profileInstallMessage = "本機伺服器啟動失敗：\(error.localizedDescription)"
                        self.stopLocalServer()
                    default:
                        break
                    }
                }
            }

            let payload = data
            listener.newConnectionHandler = { connection in
                connection.start(queue: .global(qos: .userInitiated))
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { _, _, _, _ in
                    let header = [
                        "HTTP/1.1 200 OK",
                        "Content-Type: application/x-apple-aspen-config",
                        "Content-Disposition: attachment; filename=\"Null-DNS-Shield.mobileconfig\"",
                        "Content-Length: \(payload.count)",
                        "Connection: close",
                        "",
                        ""
                    ].joined(separator: "\r\n")
                    var responseData = Data(header.utf8)
                    responseData.append(payload)
                    connection.send(content: responseData, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }

            listener.start(queue: .global(qos: .userInitiated))

            Task {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                await MainActor.run {
                    self.stopLocalServer()
                }
            }
        } catch {
            profileInstallMessage = "無法建立本機安裝伺服器：\(error.localizedDescription)"
            stopLocalServer()
        }
    }

    func stopLocalServer() {
        listener?.cancel()
        listener = nil
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    func checkDirectNetworkExtensionStatus() async {
        let manager = NEDNSSettingsManager.shared()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.loadFromPreferences { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            isDirectExtensionEnabled = manager.isEnabled
            if manager.isEnabled {
                directExtensionStatus = "系統 DNS API 已直接啟用"
            } else {
                directExtensionStatus = "系統 DNS API 尚未啟用（或待使用描述檔模式）"
            }
        } catch {
            isDirectExtensionEnabled = false
            directExtensionStatus = "免費簽章不支援直接寫入系統 API，請使用上方「一鍵描述檔安裝」"
        }
    }

    func applyDirectNetworkExtension(config: DNSConfiguration) async {
        isWorking = true
        defer { isWorking = false }

        let manager = NEDNSSettingsManager.shared()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.loadFromPreferences { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            let dnsSettings: NEDNSSettings
            switch config.resolvedProtocol {
            case .https:
                let doh = NEDNSOverHTTPSSettings(servers: config.resolvedServerAddresses)
                doh.serverURL = URL(string: config.resolvedDoHURL)
                dnsSettings = doh
            case .tls:
                let dot = NEDNSOverTLSSettings(servers: config.resolvedServerAddresses)
                dot.serverName = config.resolvedDoTHost
                dnsSettings = dot
            }

            manager.localizedDescription = "Null DNS · \(config.activePreset.name)"
            manager.dnsSettings = dnsSettings

            var rules: [NEOnDemandRule] = []
            if !config.excludedSSIDs.isEmpty {
                let exclude = NEOnDemandRuleDisconnect()
                exclude.ssidMatch = config.excludedSSIDs
                rules.append(exclude)
            }
            let connect = NEOnDemandRuleConnect()
            switch config.networkScope {
            case .all:
                break
            case .wifiOnly:
                connect.interfaceTypeMatch = .wiFi
            case .cellularOnly:
                connect.interfaceTypeMatch = .cellular
            }
            rules.append(connect)
            manager.onDemandRules = rules

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            isDirectExtensionEnabled = true
            directExtensionStatus = "已透過系統 NetworkExtension API 直接啟用！請至「設定 → VPN 與裝置管理 → DNS」確認勾選 Null。"
        } catch {
            isDirectExtensionEnabled = false
            directExtensionStatus = "目前簽章憑證未包含 NetworkExtension 權限（免費 Apple ID 正常現象）。請點擊上方「一鍵套用系統 DNS 描述檔」即可在免越獄 iPhone 實現完全相同的全機過濾！"
        }
    }

    private func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
