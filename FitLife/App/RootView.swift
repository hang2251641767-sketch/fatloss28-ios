import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-coach"), let plan = store.plans.first {
                FollowAlongView(plan: plan, exercises: plan.exercises)
            } else if store.profile.hasCompletedOnboarding { MainTabView() } else { OnboardingView() }
            #else
            if store.profile.hasCompletedOnboarding { MainTabView() } else { OnboardingView() }
            #endif
        }
            .tint(.green).environment(\.locale, Locale(identifier: "zh_Hans_CN"))
    }
}

struct MainTabView: View {
    @State private var selected = 0
    var body: some View {
        TabView(selection: $selected) {
            HomeView().tabItem { Label("首页", systemImage: "house.fill") }.tag(0)
            TrainingView().tabItem { Label("训练", systemImage: "dumbbell.fill") }.tag(1)
            NutritionView().tabItem { Label("饮食", systemImage: "fork.knife") }.tag(2)
            CalendarView().tabItem { Label("日历", systemImage: "calendar") }.tag(3)
            ProfileView().tabItem { Label("我的", systemImage: "person.fill") }.tag(4)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-courses") { selected = 1 }
            if ProcessInfo.processInfo.arguments.contains("--preview-nutrition") { selected = 2 }
            #endif
        }
    }
}
