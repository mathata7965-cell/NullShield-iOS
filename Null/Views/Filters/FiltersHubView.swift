import SwiftUI

struct FiltersHubView: View {
    @EnvironmentObject var store: FilterStore

    @State private var showCustomRules = false
    @State private var showTrackerIntel = false
    @State private var showAddSubscription = false
    @State private var newSubName = ""
    @State private var newSubURL = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerRow

                quickToolsBar

                categoriesSection

                subscriptionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showCustomRules) {
            CustomRulesSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showTrackerIntel) {
            TrackerIntelView()
                .environmentObject(store)
        }
        .alert("新增遠端過濾訂閱清單", isPresented: $showAddSubscription) {
            TextField("清單名稱（例如 EasyList TW）", text: $newSubName)
            TextField("https://.../filter.txt", text: $newSubURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("取消", role: .cancel) {
                newSubName = ""
                newSubURL = ""
            }
            Button("匯入並下載") {
                store.addSubscription(name: newSubName, urlString: newSubURL)
                newSubName = ""
                newSubURL = ""
            }
        } message: {
            Text("支援標準 AdGuard、EasyList、uBlock Origin 與 Hosts (.txt) 格式，會自動編譯為原生 WebKit 規則。")
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("過濾規則中心")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                Text("共編譯 \(store.totalCompiledRuleCount) 條 WebKit 過濾規則")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NullTheme.textSecondary)
            }
            Spacer()
            NullStatusPill(
                text: store.isMasterShieldEnabled ? "引擎啟用中" : "已暫停",
                color: store.isMasterShieldEnabled ? NullTheme.emerald : NullTheme.amber
            )
        }
    }

    private var quickToolsBar: some View {
        HStack(spacing: 10) {
            Button {
                showCustomRules = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(NullTheme.emerald)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("自訂規則 & 白名單")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(store.customRules.filter(\.isEnabled).count) 規則 · \(store.allowlistDomains.count) 例外")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NullTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(NullTheme.emerald.opacity(0.25), lineWidth: 0.9)
                )
            }
            .buttonStyle(.plain)

            Button {
                showTrackerIntel = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                        .foregroundStyle(NullTheme.cyan)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("追蹤特徵圖鑑")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(store.trackerIntel.count) 家廣告商解析")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NullTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(NullTheme.cyan.opacity(0.25), lineWidth: 0.9)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var categoriesSection: some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("內建六大核心過濾模組")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                ForEach(Array(store.categories.enumerated()), id: \.element.id) { index, cat in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                    HStack(spacing: 12) {
                        Image(systemName: cat.icon)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(cat.isEnabled ? NullTheme.emerald : NullTheme.textMuted)
                            .frame(width: 34, height: 34)
                            .background(
                                (cat.isEnabled ? NullTheme.emerald : Color.white).opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(cat.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("\(cat.rules.count) 條")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(NullTheme.cyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(NullTheme.cyan.opacity(0.12), in: Capsule())
                            }
                            Text(cat.subtitle)
                                .font(.caption2)
                                .foregroundStyle(NullTheme.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { cat.isEnabled },
                            set: { store.setCategory(cat.id, enabled: $0) }
                        ))
                        .labelsHidden()
                        .tint(NullTheme.emerald)
                    }
                }
            }
        }
    }

    private var subscriptionsSection: some View {
        NullGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("遠端訂閱過濾清單")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("支援 AdGuard / EasyList / OISD 即時下載與規則轉譯")
                            .font(.caption2)
                            .foregroundStyle(NullTheme.textSecondary)
                    }
                    Spacer()

                    Button {
                        Task { await store.updateAllEnabledSubscriptions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(NullTheme.cyan)
                            .padding(8)
                            .background(NullTheme.cyan.opacity(0.12), in: Circle())
                    }
                    .disabled(store.isUpdatingSubscriptions)

                    Button {
                        showAddSubscription = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(NullTheme.bgBase)
                            .padding(8)
                            .background(NullTheme.emerald, in: Circle())
                    }
                }

                ForEach(store.subscriptions) { sub in
                    Divider().overlay(Color.white.opacity(0.08))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(sub.categoryHint)
                                    .font(.caption2)
                                    .foregroundStyle(NullTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { sub.isEnabled },
                                set: { _ in store.toggleSubscription(sub.id) }
                            ))
                            .labelsHidden()
                            .tint(NullTheme.emerald)
                        }

                        HStack(spacing: 8) {
                            if store.updatingSubscriptionID == sub.id {
                                ProgressView().controlSize(.mini).tint(NullTheme.emerald)
                                Text("正在下載並編譯規則...")
                                    .font(.caption2)
                                    .foregroundStyle(NullTheme.emerald)
                            } else if let err = sub.lastError {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(NullTheme.amber)
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(NullTheme.amber)
                                    .lineLimit(1)
                            } else if sub.compiledRuleCount > 0 {
                                Text("已編譯 \(sub.compiledRuleCount) 條規則")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(NullTheme.emerald)
                                if let updated = sub.lastUpdated {
                                    Text("· \(updated.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundStyle(NullTheme.textMuted)
                                }
                            } else {
                                Text("尚未下載規則")
                                    .font(.caption2)
                                    .foregroundStyle(NullTheme.textMuted)
                            }

                            Spacer()

                            Button {
                                Task { await store.updateSubscription(id: sub.id) }
                            } label: {
                                Text(sub.compiledRuleCount > 0 ? "立即更新" : "下載編譯")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(NullTheme.cyan)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(NullTheme.cyan.opacity(0.12), in: Capsule())
                            }
                            .disabled(store.updatingSubscriptionID == sub.id)
                        }
                    }
                }
            }
        }
    }
}
