import SwiftUI

struct ProgramLibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var level = "全部"
    @State private var goal = "全部"
    @State private var search = ""
    private var programs: [TrainingProgram] {
        store.library.filter {
            (level == "全部" || $0.level == level) && (goal == "全部" || $0.goal == goal) &&
            (search.isEmpty || ($0.name + $0.equipment + $0.summary).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        List {
            Section("按你的节奏选择") {
                Picker("难度", selection: $level) {
                    ForEach(["全部", "初级", "中级"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                Picker("目标", selection: $goal) {
                    ForEach(["全部", "减脂", "增肌", "基础体能", "恢复"], id: \.self) { Text($0).tag($0) }
                }
                Text("全部计划随 App 存在本地，无需联网。加入后可修改动作、组次和重量。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !store.libraryError.isEmpty { Text(store.libraryError).foregroundStyle(.secondary) }
            if programs.isEmpty { Text("没有符合筛选条件的计划").foregroundStyle(.secondary) }
            ForEach(programs) { program in
                NavigationLink {
                    ProgramDetailView(program: program)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(program.name).font(.headline)
                            if program.isOriginal { Text("原定制").font(.caption.bold()).foregroundStyle(.green) }
                        }
                        Text("\(program.level) · \(program.goal) · \(program.equipment)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(program.weeks) 周 · \(program.minutes) 分钟 / 次")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
            }
        }
        .navigationTitle("本地计划库")
        .searchable(text: $search, prompt: "搜索名称或器械")
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
            Section(program.name) {
                Text(program.summary)
                Text("\(program.level) · \(program.goal) · \(program.equipment) · \(program.weeks) 周")
                    .font(.subheadline).foregroundStyle(.secondary)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                Button(store.activeEnrollment?.sourceID == program.id ? "重新开始这一计划" : "加入我的计划") {
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
        .navigationTitle(program.isOriginal ? "原定制计划" : "计划详情")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("加入 \(program.name)", isPresented: $confirming, titleVisibility: .visible) {
            Button("加入并启用") { store.joinProgram(program, start: startDate); joined = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("\(store.activeEnrollment == nil ? "" : "当前计划库方案将暂停，历史不会删除。")新方案将从所选日期开始，原动作模板不会被覆盖。")
        }
        .alert("已加入我的计划", isPresented: $joined) {
            Button("好", role: .cancel) {}
        } message: { Text("返回训练页即可查看每日安排与开始训练。") }
    }
}
