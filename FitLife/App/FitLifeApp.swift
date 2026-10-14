import SwiftUI

@main struct FitLifeApp: App {
    @StateObject private var store: AppStore
    init() {
        #if DEBUG
        let preview = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--preview-") }
        let model = preview ? AppStore(defaults: UserDefaults(suiteName: "FitLife.VisualPreview")!) : AppStore()
        if preview { model.profile.hasCompletedOnboarding = true }
        _store = StateObject(wrappedValue: model)
        #else
        _store = StateObject(wrappedValue: AppStore())
        #endif
    }
    var body: some Scene { WindowGroup { RootView().environmentObject(store) } }
}
