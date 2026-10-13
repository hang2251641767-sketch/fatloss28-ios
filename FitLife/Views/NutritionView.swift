import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var store: AppStore
    @State private var adding = false
    @State private var date = Date()
    private var entries: [NutritionEntry] { store.nutrition.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private func total(_ key: KeyPath<NutritionEntry, Double>) -> String {
        String(format: "%.0f g", entries.reduce(0) { $0 + $1[keyPath: key] })
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                    Text("热量：\(entries.reduce(0) { $0 + $1.calories }) / \(store.profile.dailyCalories) kcal").font(.headline)
                    HStack {
                        Metric(title: "蛋白质", value: total(\.protein))
                        Spacer()
                        Metric(title: "碳水", value: total(\.carbs))
                        Spacer()
                        Metric(title: "脂肪", value: total(\.fat))
                    }
                }
                Section("当日饮食") {
                    if entries.isEmpty { Text("点右上角 + 记录一餐").foregroundStyle(.secondary) }
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.meal.isEmpty ? "饮食记录" : entry.meal).font(.headline)
                            Text("\(entry.calories) kcal · 蛋白质 \(entry.protein, specifier: "%.0f")g · 碳水 \(entry.carbs, specifier: "%.0f")g · 脂肪 \(entry.fat, specifier: "%.0f")g")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.onDelete { offsets in
                        let ids = offsets.map { entries[$0].id }
                        store.nutrition.removeAll { ids.contains($0.id) }
                    }
                }
            }
            .navigationTitle("饮食")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { NutritionEditor(initialDate: date) }
        }
    }
}

struct NutritionEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var initialDate = Date()
    @State private var date = Date()
    @State private var meal = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    private var valid: Bool {
        guard let c = Int(calories), (0...20000).contains(c) else { return false }
        return [protein, carbs, fat].allSatisfy { $0.isEmpty || (NumberInput.decimal($0).map { (0...5000).contains($0) } ?? false) }
    }
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                TextField("餐次 / 食物", text: $meal)
                TextField("热量 kcal", text: $calories).keyboardType(.numberPad)
                TextField("蛋白质 g", text: $protein).keyboardType(.decimalPad)
                TextField("碳水 g", text: $carbs).keyboardType(.decimalPad)
                TextField("脂肪 g", text: $fat).keyboardType(.decimalPad)
                Text("宏量营养素可留空。").font(.footnote).foregroundStyle(.secondary)
            }
            .scrollDismissesKeyboard(.interactively).keyboardDoneButton()
            .navigationTitle("记录饮食")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard valid, let c = Int(calories) else { return }
                        store.nutrition.append(NutritionEntry(date: date, calories: c,
                            protein: NumberInput.decimal(protein) ?? 0, carbs: NumberInput.decimal(carbs) ?? 0,
                            fat: NumberInput.decimal(fat) ?? 0, meal: meal))
                        dismiss()
                    }.disabled(!valid)
                }
            }
            .onAppear { date = initialDate }
        }
    }
}
