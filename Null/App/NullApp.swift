import SwiftUI

@main
struct NullApp: App {
    @StateObject private var store = FilterStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
        }
    }
}
