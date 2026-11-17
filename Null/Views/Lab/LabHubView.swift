import SwiftUI

struct LabHubView: View {
    @EnvironmentObject var store: FilterStore
    @Binding var subTab: Int

    @StateObject private var browserController = StealthBrowserController()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Null 實驗室")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("無痕瀏覽器 · DNS 穿透雷達 · 分享連結淨化")
                        .font(.caption)
                        .foregroundStyle(NullTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Picker("實驗室工具", selection: $subTab) {
                Text("Stealth 瀏覽").tag(0)
                Text("X-Ray 雷達").tag(1)
                Text("網址淨化器").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Group {
                switch subTab {
                case 0:
                    StealthBrowserView(controller: browserController)
                case 1:
                    XRayRadarView()
                default:
                    LinkSanitizerView { cleanURL in
                        subTab = 0
                        browserController.navigate(to: cleanURL)
                    }
                }
            }
        }
    }
}
