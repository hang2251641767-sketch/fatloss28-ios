import SwiftUI
import UserNotifications
import Charts

@main
struct FatLoss28App: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @AppStorage("startDate") private var startDateString = ""
    @AppStorage("weightLog") private var weightLogData = "{}"
    @AppStorage("waistLog") private var waistLogData = "{}"
    @AppStorage("doneItems") private var doneItemsData = "{}"
    @State private var selectedTab = 0
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? Date()
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @FocusState private var isEditingMeasurement: Bool
    @State private var weightInput = ""
    @State private var waistInput = ""
    @State private var savedMessage = ""

    private let ink = Color(red: 0.08, green: 0.12, blue: 0.18)
    private let green = Color(red: 0.25, green: 0.72, blue: 0.48)

    private var startDate: Date {
        if let date = ISO8601DateFormatter().date(from: startDateString) { return date }
        return Calendar.current.startOfDay(for: Date())
    }
    private var dayNumber: Int {
        max(1, min(28, (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) + 1))
    }
    private func dateKey(_ date: Date) -> String { ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date)) }
    private var todayKey: String { dateKey(Date()) }
    private var selectedKey: String { dateKey(selectedDate) }
    private var selectedDayNumber: Int { max(1, (Calendar.current.dateComponents([.day], from: startDate, to: selectedDate).day ?? 0) + 1) }
    private var selectedIndex: Int { (selectedDayNumber - 1) % 7 }
    private var selectedItems: [String] { training[selectedIndex] }
    private var isWithinPlan: Bool { selectedDayNumber >= 1 && selectedDayNumber <= 28 && selectedDate >= Calendar.current.startOfDay(for: startDate) }
    private func logDict(_ value: String) -> [String:String] {
        guard let data = value.data(using: .utf8), let result = try? JSONDecoder().decode([String:String].self, from: data) else { return [:] }
        return result
    }
    private func saveLog(_ value: [String:String]) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    private func dayCompleted(_ date: Date) -> Bool {
        let d = Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? -1
        guard d >= 0 && d < 28 else { return false }
        let items = training[d % 7]
        return items.allSatisfy { doneDict[dateKey(date)]?[$0] == true }
    }

    private let training: [[String]] = [
        ["哑铃平板卧推 2组×10–12次","单臂哑铃划船 2组×每侧10–12次","坐姿哑铃推举 2组×8–12次","哑铃弯举 2组×12次","平板支撑 2组×20–30秒"],
        ["徒手/轻哑铃深蹲 2组×10–12次","哑铃罗马尼亚硬拉 2组×10–12次","臀桥 2组×15次","提踵 2组×15次","死虫式 2组×每侧8–10次"],
        ["轻松步行或原地踏步 15–20分钟","胸肩髋轻柔拉伸 5分钟"],
        ["上斜哑铃卧推 2组×10–12次","胸托哑铃划船 2组×10–12次","哑铃侧平举 2组×12–15次","哑铃过头臂屈伸 2组×10–12次","鸟狗式 2组×每侧8–10次"],
        ["轻松步行 15–25分钟","每坐1小时起身活动"],
        ["高脚杯深蹲 2组×10–12次","哑铃罗马尼亚硬拉 2组×10次","反向弓步 2组×每侧8次","臀桥 2组×15次","侧平板支撑 2组×每侧15–25秒"],
        ["休息或轻松散步 10–20分钟"]
    ]
    private let dayNames = ["上肢A","下肢A","低强度活动","上肢B","恢复步行","下肢B+核心","休息/散步"]

    private var weightsSorted: [(date: Date, value: Double)] {
        logDict(weightLogData).compactMap { key, value in
            guard let date = ISO8601DateFormatter().date(from: key),
                  let number = Double(value.replacingOccurrences(of: ",", with: ".")),
                  number > 0 else { return nil }
            return (date: date, value: number)
        }.sorted { $0.date < $1.date }
    }
    private var latestWeight: Double? { weightsSorted.last?.value }
    private var completedDays: Int {
        (0..<28).filter { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: startDate), date <= Date() else { return false }
            return dayCompleted(date)
        }.count
    }
    private var streakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let base = dayCompleted(today) ? today : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
        var count = 0
        for offset in 0..<28 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: base), dayCompleted(date) else { break }
            count += 1
        }
        return count
    }
    private var chartPoints: [(date: Date, value: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        return weightsSorted.filter { $0.date >= cutoff && $0.date <= Date() }
    }
    private var trainingIndex: Int { (dayNumber - 1) % 7 }
    private var todaysItems: [String] { training[trainingIndex] }

    private func decodeDict(_ value: String) -> [String: [String: Bool]] {
        guard let data = value.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [String: Bool]].self, from: data) else { return [:] }
        return dict
    }
    private func encodeDict(_ dict: [String: [String: Bool]]) -> String {
        guard let data = try? JSONEncoder().encode(dict) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    private var doneDict: [String: [String: Bool]] { decodeDict(doneItemsData) }
    private func isDone(_ item: String) -> Bool { doneDict[selectedKey]?[item] ?? false }
    private func toggle(_ item: String) {
        var dict = doneDict
        var today = dict[selectedKey] ?? [:]
        today[item] = !(today[item] ?? false)
        dict[selectedKey] = today
        doneItemsData = encodeDict(dict)
    }
    private var completedCount: Int { selectedItems.filter { isDone($0) }.count }
    private var progress: Double { selectedItems.isEmpty ? 0 : Double(completedCount) / Double(selectedItems.count) }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("今天也要好好照顾自己").font(.title2.bold())
                            Text(Date().formatted(date: .complete, time: .omitted)).foregroundColor(.secondary)
                        }
                        HStack(spacing: 10) {
                            dashboardCard("当前体重", latestWeight.map { String(format: "%.1f kg", $0) } ?? "待记录", "scalemass")
                            dashboardCard("目标体重", "65 kg", "flag.checkered")
                        }
                        HStack(spacing: 10) {
                            dashboardCard("已完成训练", "\(completedDays) / 28 天", "checkmark.seal")
                            dashboardCard("连续打卡", "\(streakDays) 天", "flame")
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("28天计划进度").font(.headline)
                            ProgressView(value: Double(completedDays), total: 28).tint(green)
                            Text("已完成 \(completedDays) 天 · 今天\(dayCompleted(Date()) ? "已完成 ✓" : "尚未完成")")
                                .font(.subheadline).foregroundColor(.secondary)
                            Button("开始今天的训练") {
                                selectedDate = Calendar.current.startOfDay(for: Date())
                                selectedTab = 1
                            }.buttonStyle(.borderedProminent)
                        }.padding().background(Color(.secondarySystemBackground)).cornerRadius(18)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("近30天体重趋势").font(.headline)
                                Spacer()
                                Button("记录体重") {
                                    selectedDate = Calendar.current.startOfDay(for: Date())
                                    selectedTab = 4
                                }.font(.subheadline)
                            }
                            if chartPoints.count >= 2 {
                                Chart(chartPoints, id: \.date) { point in
                                    LineMark(x: .value("日期", point.date), y: .value("体重", point.value))
                                        .foregroundStyle(green)
                                    PointMark(x: .value("日期", point.date), y: .value("体重", point.value))
                                        .foregroundStyle(green)
                                }
                                .chartYScale(domain: chartRange)
                                .frame(height: 210)
                            } else {
                                Text("至少记录两天体重，就能看到变化曲线。")
                                    .foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 110)
                            }
                            Text("每日体重会有正常波动，建议关注7天平均趋势。")
                                .font(.caption).foregroundColor(.secondary)
                        }.padding().background(Color(.secondarySystemBackground)).cornerRadius(18)
                    }.padding()
                }.navigationTitle("首页")
            }.tabItem { Label("首页", systemImage: "house.fill") }.tag(0)

            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 24).fill(ink)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("28天居家减脂计划").font(.title2.bold()).foregroundColor(.white)
                                Text("第 \(dayNumber) / 28 天 · 稳定坚持，比拼命更重要").font(.subheadline).foregroundColor(.white.opacity(0.78))
                                ProgressView(value: Double(dayNumber), total: 28).tint(green).padding(.top, 8)
                                Text("所选日期训练完成 \(completedCount)/\(selectedItems.count)").font(.subheadline.bold()).foregroundColor(.white)
                            }.padding(20)
                        }.frame(height: 160)

                        HStack {
                            Text("训练日期").font(.headline)
                            Spacer()
                            DatePicker("", selection: $selectedDate, displayedComponents: .date).labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("所选日期：\(dayNames[selectedIndex])").font(.title3.bold())
                            Text("每组保留约3–4次余力，不要练到力竭；不舒服就停止。").font(.footnote).foregroundColor(.secondary)
                            ForEach(selectedItems, id: \.self) { item in
                                Button { toggle(item) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isDone(item) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3).foregroundColor(isDone(item) ? green : .secondary)
                                        Text(item).foregroundColor(.primary).multilineTextAlignment(.leading)
                                        Spacer()
                                    }.padding(13).background(Color(.secondarySystemBackground)).cornerRadius(14)
                                }.buttonStyle(.plain)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("每日目标").font(.headline)
                            HStack {
                                targetChip("热量", "约 2000 kcal")
                                targetChip("蛋白质", "140–160 g")
                            }
                            Text("2000 kcal 是起始估算值，根据连续2–3周的体重均值再调整。").font(.footnote).foregroundColor(.secondary)
                        }
                    }.padding()
                }
                .navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("训练", systemImage: "figure.strengthtraining.traditional") }.tag(1)

            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthCalendar
                        Text("选择日期查看打卡和体重").font(.footnote).foregroundColor(.secondary)
                        Text("\(selectedDate.formatted(date: .abbreviated, time: .omitted)) · \(dayCompleted(selectedDate) ? "训练已完成 ✓" : "训练未完成")").font(.headline)
                        if let w = logDict(weightLogData)[selectedKey] { Text("体重：\(w) kg") }
                        if let waist = logDict(waistLogData)[selectedKey] { Text("腰围：\(waist) cm") }
                        Button("前往记录") { selectedTab = 4 }
                    }.padding()
                }.navigationTitle("打卡日历")
            }.tabItem { Label("日历", systemImage: "calendar") }.tag(2)

            NavigationView {
                List {
                    Section("早餐参考") {
                        meal("燕麦 50g、牛奶 250ml、鸡蛋 2个、香蕉 100g")
                    }
                    Section("午餐参考") {
                        meal("熟米饭 200g、熟鸡胸肉 180g、蔬菜 250g、烹调油约 8g")
                    }
                    Section("加餐参考") {
                        meal("高蛋白酸奶 200g；乳清蛋白 25g（可按实际需要替换）")
                    }
                    Section("晚餐参考") {
                        meal("熟米饭 150g、瘦牛肉 150g、蔬菜 250g、烹调油约 5–8g")
                    }
                    Section("执行提醒") {
                        Text("食材重量要区分生重和熟重；品牌和做法会影响热量。每天优先保证蛋白质、蔬菜和饮水，不必追求每餐完全一样。")
                    }
                }.navigationTitle("饮食计划")
            }.tabItem { Label("饮食", systemImage: "fork.knife") }.tag(3)

            NavigationView {
                Form {
                    Section("记录日期：\(selectedDate.formatted(date: .numeric, time: .omitted))") {
                        HStack { Text("体重（kg）"); TextField("例如 79.6", text: $weightInput).keyboardType(.decimalPad).focused($isEditingMeasurement) }
                        HStack { Text("腰围（cm）"); TextField("例如 91", text: $waistInput).keyboardType(.decimalPad).focused($isEditingMeasurement) }
                        Button("保存记录") { saveMeasurements(); isEditingMeasurement = false }
                        if !savedMessage.isEmpty { Text(savedMessage).foregroundColor(.green) }
                    }
                    Section("最近体重记录") {
                        ForEach(logDict(weightLogData).keys.sorted().reversed(), id: \.self) { key in
                            HStack { Text(String(key.prefix(10))); Spacer(); Text("\(logDict(weightLogData)[key] ?? "") kg") }
                        }
                    }
                    Section("记录说明") {
                        Text("建议每天起床、上厕所后、进食前称重。观察7天平均值，不要被单日波动影响；腰围每两周测一次即可。")
                        Text("合理目标约每周下降 0.3–0.7kg。若持续快速下降并伴随乏力或力量明显下降，适当增加摄入并降低训练量。")
                    }
                    Section("当前计划") {
                        LabeledContent("计划天数", value: "28 天")
                        LabeledContent("当前进度", value: "第 \(dayNumber) 天")
                    }
                }.navigationTitle("进度记录")
                    .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { isEditingMeasurement = false } } }
                    .scrollDismissesKeyboard(.interactively)
            }.tabItem { Label("体重", systemImage: "chart.line.uptrend.xyaxis") }.tag(4)

            NavigationView {
                List {
                    Section("每日训练提醒") {
                        Toggle("开启每日提醒", isOn: $reminderEnabled)
                            .onChange(of: reminderEnabled) { enabled in
                                if enabled { scheduleReminder() } else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-training"]) }
                            }
                        DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _ in if reminderEnabled { scheduleReminder() } }
                        Text("首次开启会请求通知权限。若拒绝授权，请在 iPhone 设置中为本应用开启通知。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Section("训练原则") {
                        Text("前两周以恢复习惯为主；如果动作标准、恢复良好，之后再逐渐增加组数或重量。")
                        Text("每周可做2–3次轻松步行，从15分钟开始，逐步增加；不需要一开始就追求高强度。")
                    }
                    Section("安全提醒") {
                        Text("单纯出汗不一定代表问题；但如果轻微活动就出现明显异常气喘、胸闷、心悸、头晕或胸痛，应停止运动并及时就医。")
                    }
                    Section("数据保存") {
                        Text("打卡和记录保存在本机应用数据中。卸载应用或清除数据可能导致记录丢失。")
                    }
                    Section("重新开始") {
                        Button("重新开始28天计划", role: .destructive) {
                            startDateString = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
                            doneItemsData = "{}"
                            savedMessage = "计划已重新开始"
                        }
                    }
                }.navigationTitle("使用指南")
            }.tabItem { Label("设置", systemImage: "bell") }.tag(5)
        }
        .tint(green)
        .onChange(of: selectedDate) { _ in
            weightInput = logDict(weightLogData)[selectedKey] ?? ""
            waistInput = logDict(waistLogData)[selectedKey] ?? ""
            savedMessage = ""
            isEditingMeasurement = false
        }
        .onAppear {
            if let value = logDict(weightLogData)[selectedKey] { weightInput = value }
            if let value = logDict(waistLogData)[selectedKey] { waistInput = value }
            if startDateString.isEmpty {
                startDateString = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
            }
        }
    }


    private var chartRange: ClosedRange<Double> {
        let values = chartPoints.map(\.value)
        let low = values.min() ?? 60
        let high = values.max() ?? 80
        return (low - 1)...(high + 1)
    }
    private func dashboardCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol).foregroundColor(green).font(.title3)
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Color(.secondarySystemBackground)).cornerRadius(16)
    }

    private var monthCalendar: some View {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let offset = (cal.component(.weekday, from: first) + 5) % 7
        return VStack(spacing: 14) {
            HStack {
                Button { displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(first.formatted(.dateTime.year().month(.wide))).font(.headline)
                Spacer()
                Button { displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth } label: { Image(systemName: "chevron.right") }
            }
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.caption).foregroundColor(.secondary) }
                ForEach(0..<(offset + days), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: 44) }
                    else {
                        let day = index - offset + 1
                        let date = cal.date(byAdding: .day, value: day - 1, to: first) ?? first
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(day)").font(.subheadline.weight(cal.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular))
                                Circle().fill(dayCompleted(date) ? green : Color.clear).frame(width: 6, height: 6)
                            }.frame(maxWidth: .infinity).frame(height: 44)
                                .background(cal.isDate(date, inSameDayAs: selectedDate) ? green.opacity(0.18) : Color.clear)
                                .cornerRadius(10)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }.padding().background(Color(.secondarySystemBackground)).cornerRadius(18)
    }

    private func scheduleReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { reminderEnabled = false }
                return
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-training"])
            let content = UNMutableNotificationContent()
            content.title = "今天也来完成训练吧"
            content.body = "打开28天减脂打卡，完成今天的训练清单。"
            content.sound = .default
            let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            let request = UNNotificationRequest(identifier: "daily-training", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func targetChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.bold())
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Color(.secondarySystemBackground)).cornerRadius(12)
    }
    private func meal(_ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle").foregroundColor(green)
            Text(value)
        }.padding(.vertical, 4)
    }
    private func saveMeasurements() {
        var weights = (try? JSONSerialization.jsonObject(with: Data(weightLogData.utf8))) as? [String: String] ?? [:]
        var waists = (try? JSONSerialization.jsonObject(with: Data(waistLogData.utf8))) as? [String: String] ?? [:]
        if !weightInput.trimmingCharacters(in: .whitespaces).isEmpty { weights[selectedKey] = weightInput }
        if !waistInput.trimmingCharacters(in: .whitespaces).isEmpty { waists[selectedKey] = waistInput }
        if let data = try? JSONSerialization.data(withJSONObject: weights), let s = String(data: data, encoding: .utf8) { weightLogData = s }
        if let data = try? JSONSerialization.data(withJSONObject: waists), let s = String(data: data, encoding: .utf8) { waistLogData = s }
        savedMessage = "已保存本机记录"
    }
}
