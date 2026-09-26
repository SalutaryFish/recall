import SwiftUI

@main
struct RecallApp: App {
    @State private var store: AppStore = AppStore.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
