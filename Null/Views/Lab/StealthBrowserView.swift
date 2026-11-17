import SwiftUI
import WebKit

private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

@MainActor
final class StealthBrowserController: ObservableObject {
    @Published var urlInput: String = "null://lab-test"
    @Published var currentTitle: String = "Null 廣告攔截實測靶場"
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var shieldEnabledInBrowser: Bool = true
    @Published var pageHiddenElementsCount: Int = 0
    @Published var pageBlockedRequestsCount: Int = 0
    @Published var pageSanitizedParamsCount: Int = 0
    @Published var detectedTrackers: [String] = []
    @Published var statusToast: String?

    fileprivate weak var webView: WKWebView?
    fileprivate var lastCompiledJSON: String = ""
    fileprivate var lastAppliedShieldState: Bool = true

    var totalPageBlocked: Int {
        pageHiddenElementsCount + pageBlockedRequestsCount
    }

    func navigate(to raw: String, recordSanitize: (() -> Void)? = nil) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        resetPageTelemetry()

        if trimmed.lowercased() == "null://lab-test" {
            urlInput = "null://lab-test"
            currentTitle = "Null 廣告攔截實測靶場"
            webView?.loadHTMLString(Self.labTestHTML, baseURL: URL(string: "https://lab.nullshield.local/"))
            return
        }

        let targetString: String
        if trimmed.contains("://") {
            targetString = trimmed
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            targetString = "https://\(trimmed)"
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            targetString = "https://duckduckgo.com/?q=\(encoded)"
        }

        let sanitized = LinkSanitizerService.sanitize(targetString)
        let finalString = sanitized.isValid ? sanitized.cleanedURL : targetString
        if !sanitized.strippedParams.isEmpty {
            pageSanitizedParamsCount += sanitized.strippedParams.count
            recordSanitize?()
            statusToast = "已自動剝離 \(sanitized.strippedParams.count) 個追蹤參數"
        }

        guard let url = URL(string: finalString) else { return }
        urlInput = finalString
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }

    func reload() {
        resetPageTelemetry()
        if urlInput.lowercased() == "null://lab-test" {
            webView?.loadHTMLString(Self.labTestHTML, baseURL: URL(string: "https://lab.nullshield.local/"))
        } else {
            webView?.reload()
        }
    }

    func resetPageTelemetry() {
        pageHiddenElementsCount = 0
        pageBlockedRequestsCount = 0
        pageSanitizedParamsCount = 0
        detectedTrackers = []
    }

    func nukeIncognitoSession() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        webView?.configuration.websiteDataStore.removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor in
                self?.statusToast = "已焚毀所有無痕 Cookie、快取與本機儲存"
                self?.reload()
            }
        }
    }

    static let telemetryProbeJS: String = """
    (function() {
      var reportedHidden = 0;
      var reportedBlocked = 0;
      var seenHosts = {};
      function postUpdate() {
        try {
          window.webkit.messageHandlers.nullTelemetry.postMessage({
            hidden: reportedHidden,
            blocked: reportedBlocked,
            hosts: Object.keys(seenHosts).slice(0, 12)
          });
        } catch (e) {}
      }
      function scanPage() {
        var adSelectors = [
          '.ad-banner', '.ad-banner-wrap', '.adsbygoogle', 'ins.adsbygoogle',
          '.taboola-container', '.OUTBRAIN', '.onead-overlay', '#oneadMIP',
          '#onetrust-banner-sdk', '.cookie-banner', '.cookie-consent', '[data-ad-slot]'
        ];
        var hiddenCount = 0;
        adSelectors.forEach(function(sel) {
          document.querySelectorAll(sel).forEach(function(el) {
            var style = window.getComputedStyle(el);
            if (style && style.display === 'none') {
              hiddenCount++;
            }
          });
        });
        if (hiddenCount !== reportedHidden) {
          reportedHidden = hiddenCount;
          postUpdate();
        }
      }
      window.addEventListener('error', function(e) {
        var target = e.target;
        if (target && (target.src || target.href)) {
          var raw = target.src || target.href;
          try {
            var u = new URL(raw, window.location.href);
            if (!seenHosts[u.hostname]) {
              seenHosts[u.hostname] = true;
              reportedBlocked++;
              postUpdate();
            }
          } catch (err) {}
        }
      }, true);
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() { setTimeout(scanPage, 150); });
      } else {
        setTimeout(scanPage, 150);
      }
      setTimeout(scanPage, 700);
    })();
    """

    static let labTestHTML: String = """
    <!DOCTYPE html>
    <html lang="zh-Hant">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Null 廣告攔截實測靶場</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #0b111b; color: #f1f5f9; margin: 0; padding: 18px; line-height: 1.55; }
      .card { background: #131d2d; border: 1px solid rgba(255,255,255,0.1); border-radius: 14px; padding: 14px; margin-bottom: 14px; }
      .tag { display: inline-block; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 99px; background: rgba(0,245,160,0.16); color: #00f5a0; }
      .fake-ad { background: linear-gradient(135deg, #7f1d1d, #991b1b); border: 2px dashed #fca5a5; color: #fee2e2; padding: 14px; border-radius: 12px; margin-bottom: 12px; font-weight: 600; }
      .cookie-box { background: #3b2f0b; border: 2px solid #f59e0b; color: #fef3c7; padding: 14px; border-radius: 12px; margin-bottom: 12px; }
      h1 { font-size: 20px; margin: 8px 0; }
      p { font-size: 14px; color: #cbd5e1; margin: 6px 0; }
      .status-ok { color: #00f5a0; font-weight: 700; }
      .status-bad { color: #ff4d6d; font-weight: 700; }
    </style>
    </head>
    <body>
      <div class="card">
        <span class="tag">NULL STEALTH TEST LAB</span>
        <h1>內建廣告與追蹤防護實測靶場</h1>
        <p>本頁模擬真實網站常見的橫幅廣告、蓋版元件、Cookie 同意橫幅與跨站追蹤腳本。切換上方 <b>Null 盾牌</b> 再重整即可對比攔截效果。</p>
        <p id="tracker-probe">正在偵測第三方追蹤請求攔截狀態...</p>
      </div>

      <div class="ad-banner fake-ad">
        [模擬橫幅廣告 .ad-banner] 限時搶購！如果 Null 盾開啟，這個區塊應該被 CSS 引擎徹底隱藏。
      </div>

      <ins class="adsbygoogle fake-ad" style="display:block;">
        [模擬 Google AdSense ins.adsbygoogle] 若看到此紅框表示防護尚未開啟。
      </ins>

      <div class="taboola-container fake-ad">
        [模擬原生推薦牆 .taboola-container] 你絕對想不到的 10 個投資秘密...
      </div>

      <div class="onead-overlay fake-ad">
        [模擬台灣新聞蓋版 .onead-overlay] 全螢幕展開影音廣告測試區
      </div>

      <div id="onetrust-banner-sdk" class="cookie-banner cookie-box">
        [模擬煩人 Cookie 彈窗 #onetrust-banner-sdk] 本網站使用 482 個廣告合作夥伴追蹤您的跨站行為...
      </div>

      <div class="card">
        <b>純淨正文閱讀區</b>
        <p>當上方的紅色廣告框與黃色 Cookie 彈窗都已自動消失，代表 WebKit 內容過濾引擎已完美運作，不留空白佔位空間。</p>
      </div>

      <img src="https://pixel.facebook.com/tr?id=999999" width="1" height="1" style="display:none" id="fb-px" />
      <script src="https://www.google-analytics.com/analytics.js" id="ga-js"></script>
      <script src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js" id="ads-js"></script>
      <script>
        (function() {
          var blocked = 0;
          var total = 3;
          function markBlocked() {
            blocked++;
            var el = document.getElementById('tracker-probe');
            if (el) {
              el.innerHTML = '<span class="status-ok">✓ 已成功阻擋 ' + blocked + ' / ' + total + ' 個模擬第三方廣告與追蹤連線</span>';
            }
          }
          ['fb-px', 'ga-js', 'ads-js'].forEach(function(id) {
            var node = document.getElementById(id);
            if (node) {
              node.addEventListener('error', markBlocked);
            }
          });
          setTimeout(function() {
            if (blocked === 0) {
              var el = document.getElementById('tracker-probe');
              if (el) {
                el.innerHTML = '<span class="status-bad">⚠︎ 偵測到第三方追蹤連線未被攔截（或目前無網路／已關閉瀏覽器盾牌）</span>';
              }
            }
          }, 1200);
        })();
      </script>
    </body>
    </html>
    """
}

struct StealthBrowserView: View {
    @EnvironmentObject var store: FilterStore
    @ObservedObject var controller: StealthBrowserController

    var body: some View {
        VStack(spacing: 10) {
            addressToolbar

            hudBanner

            StealthWebViewRepresentable(
                controller: controller,
                ruleListJSON: store.compiledRuleListJSON,
                masterEnabled: store.isMasterShieldEnabled
            ) { blockedCount, kbSaved in
                store.recordBrowserBlocked(count: blockedCount, kilobytesSaved: kbSaved)
            } onSanitizeRecord: {
                store.recordSanitizedLink()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.9)
            )

            quickPresetBar
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var addressToolbar: some View {
        HStack(spacing: 8) {
            Button {
                controller.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(controller.canGoBack ? .white : NullTheme.textMuted)
                    .frame(width: 32, height: 34)
            }
            .disabled(!controller.canGoBack)

            HStack(spacing: 6) {
                Image(systemName: controller.shieldEnabledInBrowser && store.isMasterShieldEnabled ? "lock.shield.fill" : "shield.slash")
                    .font(.caption)
                    .foregroundStyle(controller.shieldEnabledInBrowser && store.isMasterShieldEnabled ? NullTheme.emerald : NullTheme.amber)

                TextField("輸入網址或搜尋關鍵字", text: $controller.urlInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .onSubmit {
                        controller.navigate(to: controller.urlInput) {
                            store.recordSanitizedLink()
                        }
                    }

                Button {
                    controller.reload()
                } label: {
                    Image(systemName: controller.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NullTheme.textSecondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                controller.shieldEnabledInBrowser.toggle()
                controller.reload()
            } label: {
                Image(systemName: controller.shieldEnabledInBrowser ? "shield.fill" : "shield.slash.fill")
                    .font(.callout)
                    .foregroundStyle(controller.shieldEnabledInBrowser ? NullTheme.bgBase : NullTheme.amber)
                    .frame(width: 34, height: 34)
                    .background(
                        controller.shieldEnabledInBrowser ? NullTheme.emerald : NullTheme.amber.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .accessibilityLabel("切換本頁廣告攔截")

            Button {
                controller.nukeIncognitoSession()
            } label: {
                Image(systemName: "flame.fill")
                    .font(.callout)
                    .foregroundStyle(NullTheme.crimson)
                    .frame(width: 34, height: 34)
                    .background(NullTheme.crimson.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("清除無痕紀錄")
        }
    }

    private var hudBanner: some View {
        HStack(spacing: 8) {
            Text(controller.currentTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if controller.pageSanitizedParamsCount > 0 {
                NullStatusPill(text: "參數淨化 \(controller.pageSanitizedParamsCount)", color: NullTheme.cyan)
            }
            NullStatusPill(
                text: "本頁隱藏/攔截 \(controller.totalPageBlocked)",
                color: controller.totalPageBlocked > 0 ? NullTheme.emerald : NullTheme.textSecondary
            )
        }
        .padding(.horizontal, 6)
    }

    private var quickPresetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip("一鍵實測靶場", icon: "target") {
                    controller.navigate(to: "null://lab-test")
                }
                quickChip("Adblock 測試站", icon: "checkmark.seal.fill") {
                    controller.navigate(to: "https://d3ward.github.io/toolz/adblock.html")
                }
                quickChip("DuckDuckGo 無痕搜尋", icon: "magnifyingglass") {
                    controller.navigate(to: "https://duckduckgo.com")
                }
                quickChip("Yahoo 奇摩新聞", icon: "newspaper.fill") {
                    controller.navigate(to: "https://tw.news.yahoo.com")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func quickChip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(NullTheme.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(NullTheme.cyan.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(NullTheme.cyan.opacity(0.25), lineWidth: 0.7))
        }
    }
}

private struct StealthWebViewRepresentable: UIViewRepresentable {
    @ObservedObject var controller: StealthBrowserController
    let ruleListJSON: String
    let masterEnabled: Bool
    let onRecordBlocked: (Int, Int) -> Void
    let onSanitizeRecord: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onRecordBlocked: onRecordBlocked, onSanitizeRecord: onSanitizeRecord)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.allowsInlineMediaPlayback = true

        let userScript = WKUserScript(
            source: StealthBrowserController.telemetryProbeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)
        let weakHandler = WeakScriptHandler(context.coordinator)
        config.userContentController.add(weakHandler, name: "nullTelemetry")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1)
        webView.allowsBackForwardNavigationGestures = true

        controller.webView = webView
        applyRules(to: webView, context: context, initialLoad: true)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let shouldEnable = masterEnabled && controller.shieldEnabledInBrowser
        if controller.lastCompiledJSON != ruleListJSON || controller.lastAppliedShieldState != shouldEnable {
            applyRules(to: webView, context: context, initialLoad: false)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "nullTelemetry")
    }

    private func applyRules(to webView: WKWebView, context: Context, initialLoad: Bool) {
        let shouldEnable = masterEnabled && controller.shieldEnabledInBrowser
        controller.lastCompiledJSON = ruleListJSON
        controller.lastAppliedShieldState = shouldEnable

        let userController = webView.configuration.userContentController
        userController.removeAllContentRuleLists()

        guard shouldEnable else {
            if initialLoad {
                controller.navigate(to: controller.urlInput)
            }
            return
        }

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "NullActiveStealthRules",
            encodedContentRuleList: ruleListJSON
        ) { ruleList, _ in
            Task { @MainActor in
                if let ruleList {
                    userController.add(ruleList)
                }
                if initialLoad {
                    controller.navigate(to: controller.urlInput)
                }
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let controller: StealthBrowserController
        let onRecordBlocked: (Int, Int) -> Void
        let onSanitizeRecord: () -> Void
        private var lastReportedSum: Int = 0

        init(
            controller: StealthBrowserController,
            onRecordBlocked: @escaping (Int, Int) -> Void,
            onSanitizeRecord: @escaping () -> Void
        ) {
            self.controller = controller
            self.onRecordBlocked = onRecordBlocked
            self.onSanitizeRecord = onSanitizeRecord
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            lastReportedSum = 0
            Task { @MainActor in
                controller.isLoading = true
                controller.canGoBack = webView.canGoBack
                controller.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                controller.isLoading = false
                controller.canGoBack = webView.canGoBack
                controller.canGoForward = webView.canGoForward
                if let title = webView.title, !title.isEmpty {
                    controller.currentTitle = title
                }
                if let currentURL = webView.url?.absoluteString,
                   !currentURL.contains("lab.nullshield.local") {
                    controller.urlInput = currentURL
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                // Keep links opening safely in the same stealth tab instead of spawning hidden popups
                if navigationAction.navigationType == .linkActivated {
                    let sanitized = LinkSanitizerService.sanitize(url.absoluteString)
                    if let cleanURL = URL(string: sanitized.isValid ? sanitized.cleanedURL : url.absoluteString) {
                        webView.load(URLRequest(url: cleanURL))
                    }
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "nullTelemetry",
                  let dict = message.body as? [String: Any] else { return }
            let hidden = dict["hidden"] as? Int ?? 0
            let blocked = dict["blocked"] as? Int ?? 0
            let hosts = dict["hosts"] as? [String] ?? []

            Task { @MainActor in
                controller.pageHiddenElementsCount = hidden
                controller.pageBlockedRequestsCount = blocked
                controller.detectedTrackers = hosts
                let total = hidden + blocked
                if total > lastReportedSum {
                    let delta = total - lastReportedSum
                    lastReportedSum = total
                    onRecordBlocked(delta, delta * 24)
                }
            }
        }
    }
}
