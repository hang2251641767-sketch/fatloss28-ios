import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var showWeight = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        HStack {
                            Metric(title: "最近体重", value: store.latestWeight.map { String(format: "%.1f kg", $0.weight) } ?? "未记录")
                            Spacer()
                            Metric(title: "目标体重", value: String(format: "%.1f kg", store.profile.targetWeight))
                        }
                        Button("记录今日体重") { showWeight = true }.buttonStyle(.borderedProminent)
                    }
                    Card {
                        Text("体重趋势").font(.headline)
                        if store.weights.isEmpty {
                            Text("记录体重后将在这里展示趋势").foregroundStyle(.secondary).frame(height: 130)
                        } else {
                            Chart(store.weights.sorted { $0.date < $1.date }) { entry in
                                LineMark(x: .value("日期", entry.date), y: .value("体重", entry.weight)).foregroundStyle(.green)
                                PointMark(x: .value("日期", entry.date), y: .value("体重", entry.weight)).foregroundStyle(.green)
                            }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 160)
                        }
                    }
                    Card {
                        Text("今日训练").font(.headline)
                        if store.todayPlans.isEmpty { Text("今天没有安排训练，享受恢复日。").foregroundStyle(.secondary) }
                        ForEach(store.todayPlans) { plan in
                            NavigationLink(plan.name) { WorkoutDetailView(planID: plan.id) }
                        }
                    }
                    Card {
                        HStack {
                            Image(systemName: "flame.fill").font(.title).foregroundStyle(.orange)
                            Metric(title: "连续体重 / 训练打卡", value: "\(store.streak) 天")
                        }
                        Text("今日热量 \(store.todayCalories) / \(store.profile.dailyCalories) kcal").foregroundStyle(.secondary)
                    }
                }.padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FitLife")
            .sheet(isPresented: $showWeight) { WeightEntryView() }
        }
    }
}

struct WeightEntryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var initialDate = Date()
    @State private var date = Date()
    @State private var text = ""
    @FocusState private var focused: Bool
    private var validWeight: Double? {
        guard let value = NumberInput.decimal(text), (20...500).contains(value) else { return nil }
        return value
    }
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("记录日期", selection: $date, in: ...Date(), displayedComponents: .date)
                TextField("体重（kg）", text: $text).keyboardType(.decimalPad).focused($focused)
                Text("同一天重复保存会更新当天体重。").font(.footnote).foregroundStyle(.secondary)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("记录体重")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { focused = false; dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { if let value = validWeight { store.addWeight(value, on: date) }; focused = false; dismiss() }
                        .disabled(validWeight == nil)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focused = false } }
            }
            .onAppear { date = initialDate; fillExisting() }
            .onChange(of: date) { _ in fillExisting() }
        }.presentationDetents([.medium, .large])
    }
    private func fillExisting() {
        text = store.weights.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
            .map { String(format: "%.1f", $0.weight) } ?? ""
    }
}
