import SwiftUI

struct ProgramLibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var level = "全部"
    @State private var goal = "全部"
    @State private var search = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var programs: [TrainingProgram] {
        store.library.filter {
            (level == "全部" || $0.level == level) && (goal == "全部" || $0.goal == goal) &&
            (search.isEmpty || ($0.displayTitle + $0.equipment + $0.summary).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("难度", selection: $level) {
                    ForEach(["全部", "初级", "中级"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["全部", "减脂", "增肌", "基础体能", "恢复"], id: \.self) { item in
                            Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { goal = item } } label: {
                                Text(item).font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, 9)
                                    .background(goal == item ? Color.green : Color(.secondarySystemGroupedBackground), in: Capsule())
                                    .foregroundStyle(goal == item ? Color.white : Color.primary)
                            }
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 18)], spacing: 18) {
                    ForEach(programs) { program in
                        NavigationLink { ProgramDetailView(program: program) } label: {
                            CourseCard(title: program.displayTitle, subtitle: "\(program.level) · \(program.equipment) · \(program.minutes) 分钟",
                                image: program.coverName, badge: "\(program.goal) · \(program.weeks) 周")
                        }.buttonStyle(SpringCardStyle()).transition(.opacity)
                    }
                }
                if programs.isEmpty { Text("没有符合筛选条件的课程").foregroundStyle(.secondary).padding() }
                if !store.libraryError.isEmpty { Text(store.libraryError).foregroundStyle(.secondary) }
            }.padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("课程库")
        .searchable(text: $search, prompt: "搜索课程名称或器械")
    }
}

struct ProgramDetailView: View {
    @EnvironmentObject var store: AppStore
    let program: TrainingProgram
    @State private var startDate = Date()
    @State private var confirming = false
    @State private var joined = false
    var body: some View {
        List {
            Section {
                CourseCard(title: program.displayTitle, subtitle: "\(program.level) · \(program.equipment)", image: program.coverName, badge: "\(program.weeks) 周课程")
                Text(program.summary)
                Text("\(program.level) · \(program.goal) · \(program.equipment) · \(program.weeks) 周")
                    .font(.subheadline).foregroundStyle(.secondary)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                Button(store.activeEnrollment?.sourceID == program.id ? "重新开始这一计划" : "订阅这门课程") {
                    confirming = true
                }.buttonStyle(.borderedProminent)
            }
            Section("执行与进阶") {
                Text(program.guidance)
                Text(program.progression).foregroundStyle(.secondary)
            }
            ForEach(program.days) { day in
                Section("第 \(day.offset + 1) 天 · \(day.name)") {
                    Text(day.instructions).font(.footnote).foregroundStyle(.secondary)
                    ForEach(Array(day.exercises.enumerated()), id: \.offset) { _, exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                            Text(exercise.prescription).font(.subheadline).foregroundStyle(.secondary)
                            if let notes = exercise.notes { Text(notes).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Section("安排说明") {
                Text("按开始日期循环每周安排，未列出的日期为休息日。一次启用一套计划库方案；切换会暂停上一套，保留它的修改和历史。自定义循环计划仍保留。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(program.source).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("课程详情")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("加入 \(program.name)", isPresented: $confirming, titleVisibility: .visible) {
            Button("订阅并启用") { store.joinProgram(program, start: startDate); joined = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("\(store.activeEnrollment == nil ? "" : "当前计划库方案将暂停，历史不会删除。")新方案将从所选日期开始，原动作模板不会被覆盖。")
        }
        .alert("已订阅课程", isPresented: $joined) {
            Button("好", role: .cancel) {}
        } message: { Text("返回训练页即可查看每日安排与开始训练。") }
    }
}
