import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @State private var name = ""
    @State private var height = "170"
    @State private var target = "60"
    private var valid: Bool {
        guard let h = NumberInput.decimal(height), let w = NumberInput.decimal(target) else { return false }
        return (80...260).contains(h) && (20...500).contains(w)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("欢迎使用 FitLife") { Text("先设置基本目标，之后随时可以修改。") }
                Section("个人资料") {
                    TextField("姓名（可选）", text: $name)
                    TextField("身高（厘米）", text: $height).keyboardType(.decimalPad)
                    TextField("目标体重（公斤）", text: $target).keyboardType(.decimalPad)
                }
                Section {
                    Button("开始使用") {
                        store.profile.name = name
                        store.profile.height = NumberInput.decimal(height) ?? 170
                        store.profile.targetWeight = NumberInput.decimal(target) ?? 60
                        store.profile.hasCompletedOnboarding = true
                    }.frame(maxWidth: .infinity).disabled(!valid)
                }
            }
            .scrollDismissesKeyboard(.interactively).keyboardDoneButton()
            .navigationTitle("FitLife")
        }
    }
}
