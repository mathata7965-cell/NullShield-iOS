import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const CATEGORIES = [
  {
    id: "ads",
    name: "基礎廣告攔截",
    subtitle: "橫幅、插頁、開屏、影音貼片與聯盟廣告",
    icon: "nosign",
    defaultEnabled: true,
    domains: [
      "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com",
      "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "adnxs.com", "rubiconproject.com",
      "pubmatic.com", "openx.net", "casalemedia.com", "criteo.com", "criteo.net", "taboola.com",
      "outbrain.com", "mgid.com", "revcontent.com", "popads.net", "popcash.net", "propellerads.com",
      "exoclick.com", "juicyads.com", "adsterra.com", "adsrvr.org", "adform.net", "mediavine.com",
      "adthrive.com", "raptive.com", "ezoic.net", "amazon-adsystem.com", "advertising.com",
      "bidswitch.net", "smartadserver.com", "teads.tv", "sharethrough.com", "triplelift.com",
      "33across.com", "sonobi.com", "spotxchange.com", "yieldmo.com", "kargo.com", "undertone.com",
      "gumgum.com", "zedo.com", "adroll.com", "media.net", "buysellads.com", "carbonads.com",
      "flashtalking.com", "serving-sys.com", "moatads.com", "doubleverify.com", "adsafeprotected.com",
      "smaato.net", "inmobi.com", "vungle.com", "applovin.com", "unityads.unity3d.com",
      "chartboost.com", "ironsrc.com", "fyber.com", "mopub.com", "startappservice.com",
      "tapjoy.com", "adcolony.com", "pangle.io", "byteoversea.com", "lijit.com", "sovrn.com",
      "indexww.com", "contextweb.com", "turn.com", "mathtag.com", "mediamath.com", "simpli.fi",
      "zemanta.com", "nativo.com", "adblade.com", "connatix.com", "primis.tech", "vdo.ai",
      "aniview.com", "streamrail.net", "springserve.com", "lkqd.net", "jwpltx.com",
      "adlightning.com", "confiant-integrations.net", "clean.gg", "prebid.org", "richaudience.com",
      "improvedigital.com", "adkernel.com", "adglare.net", "adbutler.com", "revive-adserver.net",
      "adtech.de", "adtechus.com", "atdmt.com", "admob.com", "ads.yahoo.com", "gemini.yahoo.com",
      "bingads.microsoft.com", "bat.bing.com", "ads.youtube.com", "imasdk.googleapis.com",
      "adtrafficquality.google", "fundingchoicesmessages.google.com", "pagead-googlehosted.l.google.com"
    ],
    thirdPartyRegexes: [
      "^https?://[^/]+/pagead/",
      "^https?://[^/]+/adsense/",
      "^https?://[^/]+/adserver/",
      "^https?://[^/]+/prebid[^a-zA-Z0-9]",
      "^https?://[^/]+/gpt\\.js",
      "^https?://[^/]+/ads/banner"
    ],
    cssSelectors: [
      ".adsbygoogle",
      "ins.adsbygoogle",
      "[id^=\"div-gpt-ad\"]",
      "[id^=\"google_ads_iframe\"]",
      ".taboola-container",
      "[id^=\"taboola-\"]",
      ".OUTBRAIN",
      ".ob-widget",
      ".mgid-widget",
      ".ad-banner",
      ".ad-banner-wrap",
      ".advertisement-box",
      "[data-ad-slot]",
      "[data-google-query-id]",
      ".sponsored-ad-block"
    ]
  },
  {
    id: "privacy",
    name: "隱私與追蹤防護",
    subtitle: "數據分析、跨站畫素、指紋追蹤與 App 歸因 SDK",
    icon: "eye.slash.fill",
    defaultEnabled: true,
    domains: [
      "google-analytics.com", "googletagmanager.com", "googletagservices.com", "analytics.google.com",
      "app-measurement.com", "crashlytics.com", "analytics.tiktok.com", "ads.tiktok.com",
      "business-api.tiktok.com", "pixel.facebook.com", "an.facebook.com", "ads-api.twitter.com",
      "analytics.twitter.com", "ads.linkedin.com", "px.ads.linkedin.com", "snap.licdn.com",
      "tr.snapchat.com", "sc-static.net", "ct.pinterest.com", "ads.reddit.com",
      "events.redditmedia.com", "appsflyer.com", "appsflyersdk.com", "adjust.com",
      "branch.io", "bnc.lt", "kochava.com", "singular.net", "mixpanel.com",
      "amplitude.com", "segment.io", "segment.com", "heap.io", "heapanalytics.com",
      "hotjar.com", "hotjar.io", "fullstory.com", "logrocket.com", "mouseflow.com",
      "crazyegg.com", "clarity.ms", "luckyorange.com", "inspectlet.com", "newrelic.com",
      "nr-data.net", "bugsnag.com", "sentry.io", "ingest.sentry.io", "scorecardresearch.com",
      "quantserve.com", "chartbeat.com", "chartbeat.net", "parsely.com", "omtrdc.net",
      "demdex.net", "everesttech.net", "krxd.net", "bluekai.com", "exelator.com",
      "rlcdn.com", "tapad.com", "liveramp.com", "agkn.com", "permutive.com",
      "id5-sync.com", "uidapi.com", "fingerprintjs.com", "fpjs.io", "braze.com",
      "onesignal.com", "clevertap.com", "moengage.com", "webengage.com", "adobedtm.com",
      "tiqcdn.com", "tealiumiq.com", "ensighten.com", "mxpnl.com", "rudderstack.com",
      "snowplowanalytics.com", "plausible.io", "matomo.cloud", "kissmetrics.com", "optimizely.com",
      "abtasty.com", "vwo.com", "visualwebsiteoptimizer.com", "bounceexchange.com", "bouncex.net",
      "criteo.com", "crwdcntrl.net", "lotame.com", "eyeota.net", "narrative.io",
      "neustar.biz", "oracleinfinity.io", "pardot.com", "eulerian.net", "eulerian.com",
      "commander1.com", "tagcommander.com", "keywee.co", "taboola.com"
    ],
    thirdPartyRegexes: [
      "^https?://[^/]+/gtm\\.js",
      "^https?://[^/]+/gtag/js",
      "^https?://[^/]+/fbevents\\.js",
      "^https?://[^/]+/analytics\\.js",
      "^https?://[^/]+/collect\\?v=",
      "^https?://[^/]+/pixel\\?"
    ],
    cssSelectors: [
      "img[src*=\"pixel.facebook.com\"]",
      "img[src*=\"scorecardresearch.com\"]"
    ]
  },
  {
    id: "annoyances",
    name: "煩人元素與彈窗",
    subtitle: "Cookie 同意橫幅、App 導流蓋版與客服氣泡",
    icon: "sparkles.rectangle.stack.fill",
    defaultEnabled: true,
    domains: [
      "cookielaw.org", "onetrust.com", "cookiebot.com", "consensu.org", "trustarc.com",
      "evidon.com", "cookieyes.com", "iubenda.com", "usercentrics.eu", "didomi.io",
      "termly.io", "osano.com", "privacymanager.io", "cookiepro.com", "civiccomputing.com",
      "quantcast.mgr.consensu.org", "sourcepoint.mgr.consensu.org", "app.link", "smartbanner.js",
      "intercom.io", "intercomcdn.com", "drift.com", "driftt.com", "tawk.to",
      "crisp.chat", "zendesk.com", "zdassets.com", "livechatinc.com", "olark.com",
      "hellobar.com", "sumo.com", "sumome.com", "optinmonster.com", "privy.com",
      "sleeknote.com", "wisepops.com", "wheelio-app.com", "justuno.com", "klaviyo.com"
    ],
    thirdPartyRegexes: [
      "^https?://[^/]+/cookieconsent",
      "^https?://[^/]+/smartbanner"
    ],
    cssSelectors: [
      "#onetrust-banner-sdk",
      "#onetrust-consent-sdk",
      "#CybotCookiebotDialog",
      ".cc-window",
      ".cc-banner",
      ".cookie-banner",
      ".cookie-consent",
      ".cookie-notice",
      ".gdpr-banner",
      ".fc-consent-root",
      ".fc-ab-root",
      "[id*=\"cookie-consent\"]",
      "[class*=\"cookie-consent\"]",
      ".smartbanner",
      ".app-download-banner",
      "#intercom-container",
      ".intercom-lightweight-app",
      "#drift-widget",
      ".crisp-client"
    ]
  },
  {
    id: "social",
    name: "社群追蹤與分享鈕",
    subtitle: "第三方嵌入按鈕、社群像素與外嵌追蹤框",
    icon: "person.2.slash.fill",
    defaultEnabled: false,
    domains: [
      "addthis.com", "s7.addthis.com", "sharethis.com", "addtoany.com", "static.addtoany.com",
      "po.st", "shareaholic.com", "sumome.com", "syndication.twitter.com", "platform.twitter.com",
      "platform.linkedin.com", "platform.instagram.com", "connect.facebook.net",
      "referrer.disqus.com", "glitter.services.disqus.com", "j.kissmetrics.com"
    ],
    thirdPartyRegexes: [
      "^https?://[^/]+/widgets\\.js",
      "^https?://[^/]+/addthis_widget\\.js"
    ],
    cssSelectors: [
      ".addthis_toolbox",
      ".sharethis-inline-share-buttons",
      ".a2a_kit",
      ".social-share-floating",
      ".fb-like-box"
    ]
  },
  {
    id: "regional",
    name: "繁中與亞太區域強化",
    subtitle: "台灣／華語新聞蓋版、內容農場推薦與亞洲廣告聯盟",
    icon: "globe.asia.australia.fill",
    defaultEnabled: true,
    domains: [
      "innity.com", "innity.net", "bridgewell.com", "tenmax.io", "popin.cc", "dable.io",
      "microad.net", "microad.jp", "geniee.jp", "gmossp-sp.jp", "adingo.jp", "ad-stir.com",
      "nend.net", "imobile.co.jp", "i-mobile.co.jp", "fluct.jp", "yads.yahoo.co.jp",
      "yads.c.yimg.jp", "scupio.com", "adbert.com.tw", "tagtoo.com.tw", "tagtoo.co",
      "onead.com.tw", "onead.tw", "clickforce.com.tw", "holmesmind.com", "ad.pixnet.net",
      "falcon.pixnet.net", "ad.ettoday.net", "ad2.ettoday.net", "aotter.net", "aotter.com",
      "trek.aotter.net", "tr.line.me", "ad.line.me", "ads-api.line.me", "doubleclick-cn.net",
      "googlesyndication-cn.com", "pos.baidu.com", "cpro.baidustatic.com", "hm.baidu.com",
      "union.sogou.com", "ad.qq.com", "l.qq.com", "gdt.qq.com", "tanx.com",
      "mmstat.com", "cnzz.com", "umeng.com", "cydersoft.com", "vpon.com",
      "adlocus.com", "tamoco.com", "pad.zol.com.cn", "mediav.com", "miaozhen.com",
      "admaster.com.cn", "irs01.com", "wrating.com", "allyes.com", "gridsumdissector.com"
    ],
    thirdPartyRegexes: [
      "^https?://static\\.ettoday\\.net/ad",
      "^https?://[^/]+/onead",
      "^https?://[^/]+/innity"
    ],
    cssSelectors: [
      ".onead-overlay",
      "#oneadMIP",
      "#oneadIR",
      ".innity-apps-underlay",
      ".dable_placeholder",
      ".popin_recommend",
      "[id^=\"dablewidget_\"]",
      "[id^=\"_popIn_recommend\"]",
      ".tenmax-ad",
      ".clickforce-ad"
    ]
  },
  {
    id: "security",
    name: "惡意網域與挖礦防護",
    subtitle: "瀏覽器加密挖礦腳本、惡意推播綁架與高風險跳轉",
    icon: "lock.shield.fill",
    defaultEnabled: true,
    domains: [
      "coinhive.com", "coin-hive.com", "authedmine.com", "crypto-loot.com", "cryptoloot.pro",
      "webminepool.com", "jsecoin.com", "minero.cc", "ppoi.org", "coinimp.com",
      "browsermine.com", "coinerra.com", "ad-maven.com", "admaven.com", "hilltopads.net",
      "onclickalgo.com", "pushame.com", "pushance.com", "notifpush.com", "revpush.com",
      "monetag.com", "alexametrics.com", "trafficjunky.net", "realsrv.com", "tsyndicate.com",
      "ero-advertising.com", "exosrv.com", "popundertotal.com", "popunderjs.com", "adxpansion.com",
      "adf.ly", "shorte.st", "ouo.io", "bc.vc", "linkbucks.com",
      "clksite.com", "clkmon.com", "deloplen.com", "oclasrv.com", "acscdn.com",
      "onclasrv.com", "betteradsystem.com", "superfish.com", "conduit.com", "sweetpacks.com"
    ],
    thirdPartyRegexes: [
      "^https?://[^/]+/coinhive",
      "^https?://[^/]+/cryptonight"
    ],
    cssSelectors: [
      ".admaven-overlay",
      ".popunder-trigger"
    ]
  }
];

const TRACKER_INTEL = [
  { domain: "doubleclick.net", vendor: "Google Marketing Platform", category: "廣告投放與競價", risk: "high", summary: "Google 核心跨站廣告投放與再行銷網域，廣泛追蹤瀏覽偏好並載入橫幅與影音貼片廣告。" },
  { domain: "googlesyndication.com", vendor: "Google AdSense", category: "廣告聯播網", risk: "high", summary: "負責傳遞網頁端 Google AdSense 與 AdManager 廣告腳本與區塊。" },
  { domain: "google-analytics.com", vendor: "Google Analytics", category: "行為分析追蹤", risk: "medium", summary: "蒐集頁面停留、裝置指紋與轉換漏斗，可能與 Google 廣告帳戶關聯。" },
  { domain: "googletagmanager.com", vendor: "Google Tag Manager", category: "標籤與追蹤器容器", risk: "medium", summary: "動態載入網站埋設的各類第三方追蹤像素與行銷腳本。" },
  { domain: "pixel.facebook.com", vendor: "Meta Platforms", category: "跨站追蹤像素", risk: "high", summary: "回傳用戶造訪頁面、加購與瀏覽紀錄至 Meta 廣告系統進行精準受眾鎖定。" },
  { domain: "connect.facebook.net", vendor: "Meta SDK", category: "社群嵌入式追蹤", risk: "medium", summary: "提供 FB 分享／像素／外嵌按鈕，載入後可協助追蹤跨站用戶識別。" },
  { domain: "analytics.tiktok.com", vendor: "ByteDance / TikTok", category: "行為與裝置歸因", risk: "high", summary: "TikTok Web Pixel 與事件追蹤端點，蒐集瀏覽器參數與點擊來源。" },
  { domain: "pangle.io", vendor: "ByteDance Pangle", category: "行動廣告聯盟", risk: "high", summary: "亞太地區常見行動 App 插頁與激勵影音廣告 SDK 網路。" },
  { domain: "taboola.com", vendor: "Taboola", category: "原生廣告／內容推薦", risk: "high", summary: "常出現於新聞文章底部的「猜你喜歡」多格廣告與導流推薦牆。" },
  { domain: "outbrain.com", vendor: "Outbrain", category: "原生廣告／內容推薦", risk: "high", summary: "新聞媒體常見之贊助內容推薦引擎與點擊追蹤系統。" },
  { domain: "criteo.com", vendor: "Criteo", category: "動態再行銷廣告", risk: "high", summary: "電商商品跨站追蹤與個人化再行銷競價網路。" },
  { domain: "appsflyer.com", vendor: "AppsFlyer", category: "行動歸因遙測", risk: "high", summary: "App 安裝來源歸因與深度連結事件追蹤平台。" },
  { domain: "adjust.com", vendor: "Adjust", category: "行動歸因遙測", risk: "high", summary: "追蹤 App 內互動、廣告轉換與裝置廣告識別碼 (IDFA)。" },
  { domain: "hotjar.com", vendor: "Hotjar", category: "螢幕錄製與熱點追蹤", risk: "medium", summary: "記錄滑鼠移動、點擊熱圖與表單輸入事件之使用者行為側錄工具。" },
  { domain: "clarity.ms", vendor: "Microsoft Clarity", category: "使用者行為側錄", risk: "medium", summary: "蒐集頁面滾動深度、點擊行為與工作階段重播。" },
  { domain: "omtrdc.net", vendor: "Adobe Analytics (Omniture)", category: "企業級遙測／CNAME 偽裝常見目標", risk: "high", summary: "常透過第一方 CNAME 子網域偽裝來繞過傳統廣告攔截器。" },
  { domain: "eulerian.net", vendor: "Eulerian Technologies", category: "第一方 CNAME 追蹤目標", risk: "high", summary: "歐洲與全球電商常用之 CNAME Cloaking 追蹤平台。" },
  { domain: "pardot.com", vendor: "Salesforce Pardot", category: "行銷自動化與 CNAME 追蹤", risk: "medium", summary: "常見被綁定於網站行銷子網域後方的 CNAME 追蹤目標。" },
  { domain: "onead.com.tw", vendor: "OneAD (果實夥伴)", category: "台灣影音／蓋版廣告", risk: "high", summary: "台灣主流新聞與入口網站常見的全版插頁、置底浮動與影音展開廣告。" },
  { domain: "innity.com", vendor: "Innity", category: "亞太互動蓋版廣告", risk: "high", summary: "亞太地區常見富媒體浮動與展開式廣告平台。" },
  { domain: "tenmax.io", vendor: "TenMax (騰學廣告)", category: "台灣原生／程序化廣告", risk: "high", summary: "台灣本地數位廣告聯播網與原生版位追蹤引擎。" },
  { domain: "dable.io", vendor: "Dable", category: "亞太內容推薦廣告", risk: "medium", summary: "華語／日韓新聞網站常見之推薦文章穿插廣告模組。" },
  { domain: "popin.cc", vendor: "popIn", category: "內容推薦聯播網", risk: "medium", summary: "新聞與部落格常見文末多欄推薦廣告區塊。" },
  { domain: "aotter.net", vendor: "Aotter (電獺)", category: "台灣數據廣告平台", risk: "medium", summary: "台灣數位媒體廣告聯播與受眾數據分析網域。" },
  { domain: "applovin.com", vendor: "AppLovin", category: "手遊內插頁廣告", risk: "high", summary: "手機遊戲內最常見的全螢幕插頁與試玩廣告伺服器。" },
  { domain: "unityads.unity3d.com", vendor: "Unity Ads", category: "手遊影音廣告", risk: "high", summary: "Unity 遊戲引擎內建廣告與獎勵影片伺服器。" },
  { domain: "ironsrc.com", vendor: "ironSource", category: "手遊中介廣告平台", risk: "high", summary: "跨 App 遊戲廣告聚合、插頁與獎勵影音投放系統。" },
  { domain: "coinhive.com", vendor: "Coinhive (Mining)", category: "惡意瀏覽器挖礦", risk: "high", summary: "未經授權利用訪客裝置 CPU 進行加密貨幣挖礦之歷史惡意腳本網域。" },
  { domain: "onetrust.com", vendor: "OneTrust CMP", category: "Cookie 同意遮罩", risk: "low", summary: "管理 GDPR / CCPA 隱私同意對話框，封鎖後可減少重複跳出的彈窗遮罩。" },
  { domain: "cookiebot.com", vendor: "Cookiebot CMP", category: "Cookie 同意遮罩", risk: "low", summary: "常見第三方 Cookie 同意彈窗管理腳本。" }
];

function escapeRegexDomain(domain) {
  return domain.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function validateWebKitRule(rule) {
  const uf = rule?.trigger?.["url-filter"];
  if (!uf || typeof uf !== "string") return false;
  // Must be pure ASCII
  for (let i = 0; i < uf.length; i++) {
    if (uf.charCodeAt(i) > 127) return false;
  }
  // Disallow regex features unsupported by WebKit DFA
  if (/\\[dwsDWSbB]|\(\?[=!<:]|\{\d+,?\d*\}/.test(uf)) return false;
  return true;
}

function buildRulesForCategory(cat) {
  const rules = [];
  const seenDomains = new Set();

  for (const rawDom of cat.domains) {
    const domain = rawDom.trim().toLowerCase();
    if (!domain || seenDomains.has(domain)) continue;
    seenDomains.add(domain);

    const escaped = escapeRegexDomain(domain);
    const trigger = {
      "url-filter": `^https?://([a-z0-9-]+\\.)*${escaped}[:/?]`,
    };
    if (cat.id === "privacy" || cat.id === "social") {
      trigger["load-type"] = ["third-party"];
    }
    rules.push({
      trigger,
      action: { type: "block" }
    });
  }

  for (const rx of cat.thirdPartyRegexes || []) {
    rules.push({
      trigger: {
        "url-filter": rx,
        "load-type": ["third-party"]
      },
      action: { type: "block" }
    });
  }

  for (const sel of cat.cssSelectors || []) {
    rules.push({
      trigger: {
        "url-filter": ".*"
      },
      action: {
        type: "css-display-none",
        selector: sel
      }
    });
  }

  return rules.filter(validateWebKitRule);
}

function main() {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const rootDir = path.dirname(__dirname);

  const packCategories = [];
  const safariBlockerRules = [];

  for (const cat of CATEGORIES) {
    const rules = buildRulesForCategory(cat);
    packCategories.push({
      id: cat.id,
      name: cat.name,
      subtitle: cat.subtitle,
      icon: cat.icon,
      defaultEnabled: cat.defaultEnabled,
      domains: Array.from(new Set(cat.domains.map((d) => d.trim().toLowerCase()))),
      rules
    });
    if (cat.defaultEnabled) {
      safariBlockerRules.push(...rules);
    }
  }

  const blockerOut = path.join(rootDir, "NullSafariBlocker", "blockerList.json");
  fs.mkdirSync(path.dirname(blockerOut), { recursive: true });
  fs.writeFileSync(blockerOut, JSON.stringify(safariBlockerRules, null, 2), "utf8");

  const filterPack = {
    version: "1.0.0",
    generatedAt: new Date().toISOString(),
    categories: packCategories,
    trackerIntel: TRACKER_INTEL
  };
  const packOut = path.join(rootDir, "Null", "Resources", "FilterPack.json");
  fs.mkdirSync(path.dirname(packOut), { recursive: true });
  fs.writeFileSync(packOut, JSON.stringify(filterPack, null, 2), "utf8");

  console.log(`Generated blockerList.json: ${safariBlockerRules.length} Safari rules`);
  console.log(`Generated FilterPack.json: ${packCategories.length} categories, ${TRACKER_INTEL.length} tracker intel records`);
}

main();
