import SwiftUI

struct TrackerIntelView: View {
    @EnvironmentObject var store: FilterStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredEntries: [TrackerIntelEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.trackerIntel }
        return store.trackerIntel.filter {
            $0.domain.lowercased().contains(q)
                || $0.vendor.lowercased().contains(q)
                || $0.category.lowercased().contains(q)
                || $0.summary.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NullAmbientBackground(isActive: store.isMasterShieldEnabled)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredEntries) { entry in
                            NullGlassCard(cornerRadius: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(entry.domain)
                                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        riskBadge(entry.risk)
                                    }

                                    HStack(spacing: 6) {
                                        Text(entry.vendor)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(NullTheme.cyan)
                                        Text("·")
                                            .foregroundStyle(NullTheme.textMuted)
                                        Text(entry.category)
                                            .font(.caption2)
                                            .foregroundStyle(NullTheme.textSecondary)
                                    }

                                    Text(entry.summary)
                                        .font(.caption)
                                        .foregroundStyle(NullTheme.textSecondary)

                                    HStack {
                                        Spacer()
                                        let alreadyAdded = store.customRules.contains { $0.rawText.contains(entry.domain) }
                                        Button {
                                            if !alreadyAdded {
                                                store.addCustomRule(rawText: "||\(entry.domain)^", note: entry.vendor)
                                            }
                                        } label: {
                                            Text(alreadyAdded ? "已在自訂規則中" : "+ 加入自訂鎖定")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(alreadyAdded ? NullTheme.emerald : NullTheme.bgBase)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(
                                                    alreadyAdded ? NullTheme.emerald.opacity(0.15) : NullTheme.emerald,
                                                    in: Capsule()
                                                )
                                        }
                                        .disabled(alreadyAdded)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .searchable(text: $searchText, prompt: "搜尋網域、廣告商（如 OneAD / Meta / Taboola）")
            }
            .navigationTitle("追蹤特徵圖鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(NullTheme.emerald)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func riskBadge(_ risk: String) -> some View {
        let color: Color
        let label: String
        switch risk.lowercased() {
        case "high":
            color = NullTheme.crimson
            label = "高風險追蹤"
        case "medium":
            color = NullTheme.amber
            label = "中度追蹤"
        default:
            color = NullTheme.cyan
            label = "干擾/彈窗"
        }
        return NullStatusPill(text: label, color: color)
    }
}
