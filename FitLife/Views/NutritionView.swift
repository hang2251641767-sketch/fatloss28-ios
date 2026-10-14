import SwiftUI
import UniformTypeIdentifiers

struct NutritionView: View {
    @State private var page = 0
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("饮食页面", selection: $page) {
                    Text("每天怎么吃").tag(0)
                    Text("我的饮食记录").tag(1)
                }.pickerStyle(.segmented).padding()
                if page == 0 { MealGuidePage() } else { NutritionDiaryView() }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("饮食")
        }
    }
}

struct MealGuidePage: View {
    @EnvironmentObject var store: AppStore
    @State private var days: [MealDay] = []
    @State private var date = Date()
    @State private var preferences = false
    @State private var notice = ""
    @State private var showNotice = false
    private var selected: MealDay? {
        let start = store.enrollments.first { $0.sourceID == ProgramLibrary.originalID }?.startDate
        let index = MealGuide.dayIndex(on: date, courseStart: start)
        return days.first { $0.id == index }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    Image("NutritionCover").resizable().scaledToFill().frame(height: 180).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("28天居家减脂 · 配套餐单").font(.title2.bold())
                        Text("7天轮换 × 4周 · 早餐 / 午餐 / 晚餐 / 加餐").font(.caption)
                    }.foregroundStyle(.white).padding(18)
                }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 22))
                Card {
                    DatePicker("查看日期", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("饮食目标：\(store.profile.dailyCalories) kcal").font(.headline)
                        Spacer()
                        Button { preferences = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("饮食偏好与个人资料")
                    }
                    Text("目标沿用“我的”设置。菜单为通用均衡参考，不仅凭体重和身高计算个人热量；过敏 / 忌口尚未确认时，请先设置。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let day = selected {
                    Card {
                        Text("轮换第 \(day.id + 1) 天 · \(day.title)").font(.headline)
                        Text("参考总量约 \(day.calories) kcal · 蛋白质约 \(day.protein, specifier: "%.0f") g").font(.subheadline)
                        Text("这是食材通用估算，品牌、做法和用油会改变数值。\(day.calories == store.profile.dailyCalories ? "" : "与当前目标不同，请按需要调整主食与用油份量，并记录实际摄入。")")
                            .font(.footnote).foregroundStyle(.secondary)
                        if store.profile.dailyCalories < 1200 {
                            Text("当前热量目标过低，不会按它自动缩减菜单。请确认目标适合你。").font(.footnote).foregroundStyle(.orange)
                        }
                    }
                    ForEach(day.meals) { meal in
                        mealCard(meal)
                    }
                } else { Text("餐单读取失败，请检查本地资源。").foregroundStyle(.secondary) }
                FoodChoicesCard()
                Card {
                    Text("如何看份量").font(.headline)
                    Text("主食与肉类按所标生 / 熟重计；牛奶、豆浆克数可近似看作毫升。蔬菜不含烹调油，油已单列。没有必须禁吃的普通食物，零食也计入全天摄入。").font(.footnote).foregroundStyle(.secondary)
                    Link("参考：中国居民膳食指南", destination: URL(string: "https://dg.cnsoc.org/")!).font(.caption)
                }
            }.padding(20)
        }
        .sheet(isPresented: $preferences) { NutritionPreferencesView() }
        .onAppear { if days.isEmpty { days = (try? MealGuide.load()) ?? [] } }
        .alert("饮食记录", isPresented: $showNotice) { Button("好", role: .cancel) {} } message: { Text(notice) }
    }
    private func mealCard(_ meal: SuggestedMeal) -> some View {
        Card {
            HStack { Text(meal.name).font(.title3.bold()); Spacer(); Text("约 \(meal.calories) kcal").font(.subheadline).foregroundStyle(.green) }
            ForEach(meal.ingredients) { ingredient in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(ingredient.name); Spacer(); Text(ingredient.amountText).font(.caption).foregroundStyle(.secondary) }
                    if let reason = ingredient.avoidReason(store.nutritionPreferences) {
                        Text("避免 / 需替换：\(reason)。核对标签及交叉接触风险。").font(.caption).foregroundStyle(.red)
                    } else if !ingredient.allergens.isEmpty {
                        Text("过敏原提示：\(ingredient.allergens.joined(separator: "、"))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(meal.note).font(.footnote).foregroundStyle(.secondary)
            let already = store.nutrition.contains { $0.guideMealID == meal.id && Calendar.current.isDate($0.date, inSameDayAs: date) }
            Button(already ? "此餐已记录" : "我按这份菜单吃了 · 记入估算") {
                let added = store.logSuggestedMeal(meal, on: date)
                notice = added ? "已记入饮食记录。若换了食物或份量，请改为记录实际摄入。" : "未重复记录；有过敏 / 忌口项时，请先替换并手动记录实际食物。"
                showNotice = true
            }.buttonStyle(.bordered).disabled(already || meal.isBlocked(store.nutritionPreferences) || Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date()))
        }
    }
}

struct FoodChoicesCard: View {
    var body: some View {
        Card {
            Text("少吃什么 / 零食怎么选").font(.headline)
            Label("优先选择", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            Text("水果一份约 150–200 g、原味无糖酸奶约 150–200 g、原味坚果小份约 10 g；按饥饿感和全天摄入选择。对其中食物过敏时避免。").font(.subheadline)
            Label("控制份量与频率", systemImage: "minus.circle.fill").foregroundStyle(.orange)
            Text("奶茶、含糖饮料、薯片、甜饼干、蛋糕、糖果、油炸小吃和酒精。尽量别边刷手机边整袋吃，先取出一小份。").font(.subheadline)
            Label("明确避免", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            Text("已知会让你过敏的食物，以及医生明确要求避免的食物。普通主食、水果和晚餐不需要一律禁吃，也不建议靠饿着代替均衡饮食。").font(.subheadline)
        }
    }
}

struct NutritionPreferencesView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var message = ""
    @State private var alert = false
    private let choices = ["乳制品", "蛋", "大豆", "坚果", "鱼", "虾", "小麦"]
    var body: some View {
        NavigationStack {
            Form {
                Section("过敏 / 明确需要避开的食物类别") {
                    ForEach(choices, id: \.self) { choice in
                        Toggle(choice, isOn: Binding(get: { store.nutritionPreferences.allergens.contains(choice) }, set: { enabled in
                            store.nutritionPreferences.allergens.removeAll { $0 == choice }
                            if enabled { store.nutritionPreferences.allergens.append(choice) }
                        }))
                    }
                    Text("这是菜单内的主要类别，不是所有过敏原清单；有过敏时仍要核对包装与烹调过程。").font(.footnote).foregroundStyle(.secondary)
                }
                Section("其他忌口") {
                    TextField("用逗号分隔，如 牛肉,虾", text: $store.nutritionPreferences.avoidedFoods)
                }
                Section("个人资料与目标") {
                    HStack { Text("身高"); TextField("厘米", value: $store.profile.height, format: .number).keyboardType(.decimalPad); Text("cm") }
                    Stepper("已有热量目标：\(store.profile.dailyCalories) kcal", value: $store.profile.dailyCalories, in: 1200...5000, step: 50)
                    Button("导入个人资料设置 JSON") { importing = true }
                    Text("导入会更新身高、记录今日体重；只有文件写明热量目标时才更新目标。原历史会保留。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .keyboardDoneButton().navigationTitle("饮食偏好")
            .toolbar { Button("完成") { dismiss() } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    try store.importPersonalDietSettings(from: url); message = "个人资料已更新"
                } catch { message = "导入失败：\(error.localizedDescription)" }
                alert = true
            }
            .alert("个人资料", isPresented: $alert) { Button("好", role: .cancel) {} } message: { Text(message) }
        }
    }
}

struct NutritionDiaryView: View {
    @EnvironmentObject var store: AppStore
    @State private var adding = false
    @State private var date = Date()
    private var entries: [NutritionEntry] { store.nutrition.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private func total(_ key: KeyPath<NutritionEntry, Double>) -> String { String(format: "%.0f g", entries.reduce(0) { $0 + $1[keyPath: key] }) }
    var body: some View {
        List {
            Section {
                DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                Text("已记录 \(entries.reduce(0) { $0 + $1.calories }) / \(store.profile.dailyCalories) kcal").font(.headline)
                HStack { Metric(title: "蛋白质", value: total(\.protein)); Spacer(); Metric(title: "碳水", value: total(\.carbs)); Spacer(); Metric(title: "脂肪", value: total(\.fat)) }
                Button("记录实际食物与份量") { adding = true }
            }
            Section("当天记录") {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.meal.isEmpty ? "饮食记录" : entry.meal).font(.headline)
                        Text("\(entry.calories) kcal · 蛋白质 \(entry.protein, specifier: "%.0f")g · 碳水 \(entry.carbs, specifier: "%.0f")g · 脂肪 \(entry.fat, specifier: "%.0f")g").font(.caption).foregroundStyle(.secondary)
                    }
                }.onDelete { offsets in let ids = offsets.map { entries[$0].id }; store.nutrition.removeAll { ids.contains($0.id) } }
            }
        }.sheet(isPresented: $adding) { NutritionEditor(initialDate: date) }
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
