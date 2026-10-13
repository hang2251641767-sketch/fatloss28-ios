import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var confirmingRestore = false
    @State private var alert = ""
    @State private var showingAlert = false
    var body: some View {
        NavigationStack {
            Form {
                Section("个人与目标") {
                    TextField("姓名", text: $store.profile.name)
                    HStack {
                        Text("身高")
                        TextField("厘米", value: $store.profile.height, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("cm")
                    }
                    HStack {
                        Text("目标体重")
                        TextField("公斤", value: $store.profile.targetWeight, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                    Stepper("每日热量 \(store.profile.dailyCalories) kcal", value: $store.profile.dailyCalories, in: 800...5000, step: 50)
                }
                Section("提醒") {
                    Toggle("每日提醒", isOn: $store.profile.reminderEnabled)
                        .onChange(of: store.profile.reminderEnabled) { _ in store.updateReminder() }
                    Stepper("提醒时间：\(store.profile.reminderHour):00", value: $store.profile.reminderHour, in: 0...23)
                        .onChange(of: store.profile.reminderHour) { _ in store.updateReminder() }
                    if !store.reminderMessage.isEmpty { Text(store.reminderMessage).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("数据备份") {
                    Button("生成 JSON 备份") {
                        do { exportURL = try store.exportData() }
                        catch { show("导出失败：\(error.localizedDescription)") }
                    }
                    if let url = exportURL { ShareLink(item: url) { Label("保存 / 分享备份文件", systemImage: "square.and.arrow.up") } }
                    Button("从 JSON 备份恢复") { confirmingRestore = true }
                    Text("恢复会替换当前记录，建议先导出备份。旧版原始记录也包含在备份文件中。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text("FitLife 4.0 · 本地记录").foregroundStyle(.secondary) }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle("我的")
            .confirmationDialog("恢复将替换当前数据", isPresented: $confirmingRestore, titleVisibility: .visible) {
                Button("选择备份并恢复", role: .destructive) { importing = true }
                Button("取消", role: .cancel) {}
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    try store.restore(from: url)
                    show("恢复成功")
                } catch { show("恢复失败：\(error.localizedDescription)") }
            }
            .alert("FitLife", isPresented: $showingAlert) { Button("好", role: .cancel) {} } message: { Text(alert) }
        }
    }
    private func show(_ text: String) { alert = text; showingAlert = true }
}
