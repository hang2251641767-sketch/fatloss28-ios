import SwiftUI

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
    private var todayKey: String { ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date())) }

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
    private func isDone(_ item: String) -> Bool { doneDict[todayKey]?[item] ?? false }
    private func toggle(_ item: String) {
        var dict = doneDict
        var today = dict[todayKey] ?? [:]
        today[item] = !(today[item] ?? false)
        dict[todayKey] = today
        doneItemsData = encodeDict(dict)
    }
    private var completedCount: Int { todaysItems.filter { isDone($0) }.count }
    private var progress: Double { todaysItems.isEmpty ? 0 : Double(completedCount) / Double(todaysItems.count) }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 24).fill(ink)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("28天居家减脂计划").font(.title2.bold()).foregroundColor(.white)
                                Text("第 \(dayNumber) / 28 天 · 稳定坚持，比拼命更重要").font(.subheadline).foregroundColor(.white.opacity(0.78))
                                ProgressView(value: Double(dayNumber), total: 28).tint(green).padding(.top, 8)
                                Text("今日训练完成 \(completedCount)/\(todaysItems.count)").font(.subheadline.bold()).foregroundColor(.white)
                            }.padding(20)
                        }.frame(height: 160)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("今日安排：\(dayNames[trainingIndex])").font(.title3.bold())
                            Text("每组保留约3–4次余力，不要练到力竭；不舒服就停止。").font(.footnote).foregroundColor(.secondary)
                            ForEach(todaysItems, id: \.self) { item in
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
            }.tabItem { Label("训练", systemImage: "figure.strengthtraining.traditional") }.tag(0)

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
            }.tabItem { Label("饮食", systemImage: "fork.knife") }.tag(1)

            NavigationView {
                Form {
                    Section("记录今天") {
                        HStack { Text("体重（kg）"); TextField("例如 79.6", text: $weightInput).keyboardType(.decimalPad) }
                        HStack { Text("腰围（cm）"); TextField("例如 91", text: $waistInput).keyboardType(.decimalPad) }
                        Button("保存记录") { saveMeasurements() }
                        if !savedMessage.isEmpty { Text(savedMessage).foregroundColor(.green) }
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
            }.tabItem { Label("进度", systemImage: "chart.line.uptrend.xyaxis") }.tag(2)

            NavigationView {
                List {
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
            }.tabItem { Label("指南", systemImage: "info.circle") }.tag(3)
        }
        .tint(green)
        .onAppear {
            if startDateString.isEmpty {
                startDateString = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
            }
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
        if !weightInput.trimmingCharacters(in: .whitespaces).isEmpty { weights[todayKey] = weightInput }
        if !waistInput.trimmingCharacters(in: .whitespaces).isEmpty { waists[todayKey] = waistInput }
        if let data = try? JSONSerialization.data(withJSONObject: weights), let s = String(data: data, encoding: .utf8) { weightLogData = s }
        if let data = try? JSONSerialization.data(withJSONObject: waists), let s = String(data: data, encoding: .utf8) { waistLogData = s }
        savedMessage = "已保存本机记录"
    }
}
