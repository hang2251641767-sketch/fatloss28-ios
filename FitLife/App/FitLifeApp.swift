import SwiftUI

@main struct FitLifeApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store) } }
}
