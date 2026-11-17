import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: FilterStore

    @State private var selectedTab: Int = 0
    @State private var labSubTab: Int = 0

    var body: some View {
        ZStack {
            NullAmbientBackground(isActive: store.isMasterShieldEnabled)

            TabView(selection: $selectedTab) {
                ShieldDashboardView(selectedTab: $selectedTab, labSubTab: $labSubTab)
                    .tabItem {
                        Label("防護核心", systemImage: "shield.lefthalf.filled")
                    }
                    .tag(0)

                FiltersHubView()
                    .tabItem {
                        Label("過濾規則", systemImage: "slider.horizontal.3")
                    }
                    .tag(1)

                DNSShieldView()
                    .tabItem {
                        Label("全機 DNS", systemImage: "network.badge.shield.half.filled")
                    }
                    .tag(2)

                LabHubView(subTab: $labSubTab)
                    .tabItem {
                        Label("實驗室", systemImage: "waveform.path.ecg")
                    }
                    .tag(3)
            }
            .tint(store.isMasterShieldEnabled ? NullTheme.emerald : NullTheme.amber)
        }
        .preferredColorScheme(.dark)
    }
}
