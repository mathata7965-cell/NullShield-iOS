# Null · 零噪盾 (iOS IPA)

**Null** 是一款專為 iPhone / iPad 打造的隱私淨化與去廣告防禦工具，完整對標 AdGuard 核心能力並針對側載環境強化實戰功能，搭配極簡俐落的曜石霓虹 `Ø` 視覺識別。

## 品牌與視覺識別

- **名稱**：`Null`（零噪盾）—— 源自網路層 `0.0.0.0` 歸零阻擋，將廣告、跨站追蹤與遙測請求直接歸零。
- **頭像 / App Icon**：黑曜石六角盾徽搭配電光翠綠 × 冰青光環與斜切 `Ø` 破盾符號，高對比極簡辨識度。

## 核心功能（對標 AdGuard + Null 獨家特色）

1. **Safari 內容阻擋器延伸功能 (`NullSafariBlocker`)**
   - 採用 Apple 原生 `SFContentBlockerManager` 與 `com.apple.Safari.content-blocker` 擴充套件架構，於 Safari 與 App 內 `SFSafariViewController` 直接攔截廣告、追蹤器、Cookie 彈窗與台灣／亞太常見新聞蓋版廣告（OneAD、Innity、TenMax、Taboola、Outbrain 等）。
   - 支援動態偵測 Safari 外掛開關狀態與規則重新載入耗時統計。

2. **全機加密 DNS 盾（跨 App 攔截廣告與遊戲插頁）**
   - 支援 **AdGuard DNS**、**AdGuard Family**、**Mullvad Adblock**、**Quad9 Security**、**NextDNS 自訂 ID**、**Control D 自訂 ID** 與 **完全自訂 DoH / DoT 端點**。
   - 內建 **On-Demand 智慧分流**（全網路 / 僅 Wi-Fi / 僅行動網路、排除特定 Wi-Fi SSID）。
   - 針對免費 Apple ID 側載環境，內建 **本機 HTTP `.mobileconfig` 一鍵描述檔安裝器** 與匯出功能；若使用付費開發者憑證或 TrollStore，亦支援直接寫入 `NEDNSSettingsManager`。

3. **AdGuard / EasyList 語法編譯與訂閱中心**
   - 內建 **6 大核心過濾模組**、**自訂規則語法即時驗證器**（支援 `||domain^`、`@@||allow^`、`##.css-selector`、`$third-party`、`hosts` 格式）、**網站白名單**與 **遠端訂閱清單下載編譯**（AdGuard DNS / Mobile Ads / EasyPrivacy / OISD）。
   - 內建 **追蹤特徵圖鑑（Tracker Intel）**，解析 30+ 常見廣告商背景與風險等級。

4. **Null 實驗室（獨家三大實戰工具）**
   - **Stealth 無痕去廣告瀏覽器**：即時編譯 `WKContentRuleListStore` 套用你的所有開關＋自訂規則＋訂閱清單，並內建離線可用的「Null 廣告攔截實測靶場」與一鍵焚毀無痕紀錄按鈕。
   - **X-Ray DNS & CNAME 穿透雷達**：並發查詢 Cloudflare 標準 DNS 與 AdGuard 過濾 DNS，實測解析對比、揭露第一方 CNAME Cloaking 偽裝追蹤並一鍵加入封鎖或白名單。
   - **分享連結追蹤碼淨化器**：自動識別並剝離超過 45 種社群與行銷追蹤參數（`utm_*`、`fbclid`、`gclid`、`igshid`、`si`、`spm` 等）。

## 產出檔案說明

- `Null.ipa`：完整版（含 Main App + `NullSafariBlocker` Safari 內容阻擋器，共需 **2 個 App ID**，適用 Sideloadly / AltStore / SideStore / TrollStore）。
- `Null-NoExtension.ipa`：單一 App ID 精簡版（僅 **1 個 App ID**，保留全機 DNS 描述檔盾、Stealth 無痕瀏覽器、X-Ray 雷達與連結淨化器）。

## Windows 雲端編譯 `.ipa`

```powershell
cd C:\Users\matha\.gemini\antigravity\scratch\NullShield_iOS
powershell -ExecutionPolicy Bypass -File .\Build-IPA-Cloud.ps1
```
