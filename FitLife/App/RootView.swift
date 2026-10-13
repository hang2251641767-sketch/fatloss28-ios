import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Group { if store.profile.hasCompletedOnboarding { MainTabView() } else { OnboardingView() } }
            .tint(.green).environment(\.locale, Locale(identifier: "zh_Hans_CN"))
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("首页", systemImage: "house.fill") }
            TrainingView().tabItem { Label("训练", systemImage: "dumbbell.fill") }
            NutritionView().tabItem { Label("饮食", systemImage: "fork.knife") }
            CalendarView().tabItem { Label("日历", systemImage: "calendar") }
            ProfileView().tabItem { Label("我的", systemImage: "person.fill") }
        }
    }
}
