import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var store: AppStore
    @State private var creating = false
    private var customPlans: [WorkoutPlan] { store.plans.filter { $0.programInstanceID == nil } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProgramLibraryView()
                    } label: {
                        Label("本地计划库 · 初级 / 中级 / 增肌 / 减脂", systemImage: "square.grid.2x2.fill")
                            .padding(.vertical, 6)
                    }
                    Text("原来的定制计划已恢复在计划库中。内置方案可离线查看和一键加入。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let current = store.activeEnrollment {
                    Section("当前计划 · \(current.name)") {
                        ProgramProgressView(enrollment: current)
                        ForEach(store.plansForEnrollment(current.id).sorted { ($0.cycleDay ?? 0) < ($1.cycleDay ?? 0) }) { plan in
                            NavigationLink { WorkoutDetailView(planID: plan.id) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("第 \((plan.cycleDay ?? 0) + 1) 天 · \(plan.name)").font(.headline)
                                    Text("\(plan.exercises.count) 个动作 / 项目").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("暂停这套方案") { store.activeEnrollmentID = nil }
                    }
                }
                Section("我的计划库方案") {
                    if store.enrollments.isEmpty { Text("先从计划库加入一套方案").foregroundStyle(.secondary) }
                    ForEach(store.enrollments.sorted { $0.startDate > $1.startDate }) { enrollment in
                        NavigationLink {
                            EnrollmentDetailView(enrollmentID: enrollment.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(enrollment.name)
                                Text(enrollment.id == store.activeEnrollmentID ? "当前启用" : "已暂停")
                                    .font(.caption).foregroundStyle(enrollment.id == store.activeEnrollmentID ? Color.green : Color.secondary)
                            }
                        }
                    }
                }
                Section("自定义每周循环计划") {
                    if customPlans.isEmpty { Text("也可以点 + 新建自己的训练日").foregroundStyle(.secondary) }
                    ForEach(customPlans) { plan in
                        NavigationLink { WorkoutDetailView(planID: plan.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name).font(.headline)
                                Text("\(weekdayName(plan.weekday)) · \(plan.exercises.count) 个动作")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.onDelete { offsets in
                        let ids = offsets.map { customPlans[$0].id }
                        store.plans.removeAll { ids.contains($0.id) }
                    }
                    Button("新建自定义计划") { creating = true }
                }
            }
            .navigationTitle("训练")
            .toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $creating) { PlanEditorView() }
        }
    }
    private func weekdayName(_ day: Int) -> String { ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][min(7, max(1, day)) - 1] }
}

struct ProgramProgressView: View {
    let enrollment: ProgramEnrollment
    private var offset: Int { enrollment.dayOffset(on: Date()) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if offset < 0 {
                Text("开始日期：\(enrollment.startDate.formatted(date: .abbreviated, time: .omitted))")
            } else if offset >= enrollment.weeks * 7 {
                Text("本周期已结束，可在计划库重新开始。")
            } else {
                Text("第 \(enrollment.week(on: Date())) / \(enrollment.weeks) 周 · 第 \(offset + 1) 天")
            }
            ProgressView(value: enrollment.progress(on: Date()))
            Text(enrollment.progression).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct EnrollmentDetailView: View {
    @EnvironmentObject var store: AppStore
    let enrollmentID: UUID
    @State private var confirmingRestart = false
    private var enrollment: ProgramEnrollment? { store.enrollments.first { $0.id == enrollmentID } }
    var body: some View {
        List {
            if let enrollment = enrollment {
                Section(enrollment.name) {
                    ProgramProgressView(enrollment: enrollment)
                    Text(enrollment.guidance).font(.footnote)
                    if store.activeEnrollmentID != enrollmentID {
                        Button("继续启用此方案") { store.activeEnrollmentID = enrollmentID }
                    }
                    Button("从今天重新开始（保留我的动作修改）") { confirmingRestart = true }
                }
                ForEach(store.plansForEnrollment(enrollmentID).sorted { ($0.cycleDay ?? 0) < ($1.cycleDay ?? 0) }) { plan in
                    NavigationLink("第 \((plan.cycleDay ?? 0) + 1) 天 · \(plan.name)") { WorkoutDetailView(planID: plan.id) }
                }
            } else { Text("方案不存在") }
        }
        .navigationTitle("我的方案")
        .confirmationDialog("重新开始周期，历史记录会保留", isPresented: $confirmingRestart, titleVisibility: .visible) {
            Button("从今天开始") { store.restartProgram(enrollmentID) }
            Button("取消", role: .cancel) {}
        }
    }
}

struct PlanEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var existingID: UUID? = nil
    @State private var name = ""
    @State private var day = 2
    var body: some View {
        NavigationStack {
            Form {
                TextField("计划名称", text: $name)
                if store.plans.first(where: { $0.id == existingID })?.programInstanceID == nil {
                    Picker("每周训练日", selection: $day) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(["周日", "周一", "周二", "周三", "周四", "周五", "周六"][weekday - 1]).tag(weekday)
                        }
                    }
                } else {
                    Text("此训练日随当前方案开始日期循环。").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existingID == nil ? "新建计划" : "编辑计划")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let id = existingID, let index = store.plans.firstIndex(where: { $0.id == id }) {
                            store.plans[index].name = name
                            store.plans[index].weekday = day
                        } else {
                            store.plans.append(WorkoutPlan(name: name, weekday: day))
                        }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let plan = store.plans.first(where: { $0.id == existingID }) { name = plan.name; day = plan.weekday }
            }
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var store: AppStore
    let planID: UUID
    @State private var exercises: [Exercise] = []
    @State private var loaded = false
    @State private var exerciseName = ""
    @State private var editing = false
    @State private var message = ""
    @State private var showingMessage = false
    var plan: WorkoutPlan? { store.plans.first { $0.id == planID } }

    var body: some View {
        List {
            if let instructions = plan?.instructions {
                Section("今日安排") { Text(instructions).font(.subheadline).foregroundStyle(.secondary) }
            }
            Section("新增动作") {
                HStack {
                    TextField("例如：深蹲", text: $exerciseName)
                    Button("添加") {
                        exercises.append(Exercise(name: exerciseName, sets: [ExerciseSet()]))
                        exerciseName = ""
                    }.disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            ForEach($exercises) { $exercise in
                Section {
                    TextField("动作名称", text: $exercise.name).font(.headline)
                    if let dose = exercise.prescription { Text("模板建议：\(dose)").font(.subheadline).foregroundStyle(.secondary) }
                    if let notes = exercise.notes { Text(notes).font(.footnote).foregroundStyle(.secondary) }
                    ForEach($exercise.sets) { $set in
                        ExerciseSetRow(set: $set)
                    }.onDelete { exercise.sets.remove(atOffsets: $0) }
                    Button("增加一组") {
                        let previous = exercise.sets.last
                        exercise.sets.append(ExerciseSet(reps: previous?.reps ?? 10, weight: previous?.weight ?? 0,
                                                        durationSeconds: previous?.durationSeconds, isChecklist: previous?.isChecklist))
                    }
                    Button("删除动作", role: .destructive) { exercises.removeAll { $0.id == exercise.id } }
                }
            }
            Section("组间休息") { RestTimerView(initialDuration: plan?.restSeconds ?? 90) }
            Section {
                Button("保存动作到循环计划") {
                    guard validExercises else { message = "请检查动作、次数、时长和重量"; showingMessage = true; return }
                    saveTemplate(); message = "已保存你的动作修改"; showingMessage = true
                }
                Button("完成今日训练") {
                    guard let plan = plan else { return }
                    guard validExercises else { message = "请检查次数、时长和重量"; showingMessage = true; return }
                    guard exercises.contains(where: { $0.sets.contains(where: { $0.completed }) }) else {
                        message = "请先勾选至少一组已完成动作"; showingMessage = true; return
                    }
                    store.completeWorkout(plan, exercises: exercises)
                    saveTemplate()
                    message = "今日训练已保存，可在日历中查看。"
                    showingMessage = true
                }
            }
        }
        .scrollDismissesKeyboard(.interactively).keyboardDoneButton()
        .navigationTitle(plan?.name ?? "训练")
        .toolbar { Button("编辑计划") { editing = true } }
        .sheet(isPresented: $editing) { PlanEditorView(existingID: planID) }
        .onAppear {
            guard !loaded else { return }
            exercises = store.workouts.first(where: { $0.planID == planID && Calendar.current.isDateInToday($0.date) })?.exercises ?? plan?.exercises ?? []
            loaded = true
        }
        .alert("训练", isPresented: $showingMessage) { Button("好", role: .cancel) {} } message: { Text(message) }
    }
    private var validExercises: Bool {
        exercises.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            $0.sets.allSatisfy { set in
                let doseValid = set.durationSeconds.map { (1...86400).contains($0) } ?? (set.reps > 0 && set.reps <= 10000)
                return doseValid && set.weight.isFinite && (0...2000).contains(set.weight)
            }
        }
    }
    private func saveTemplate() {
        guard validExercises, let index = store.plans.firstIndex(where: { $0.id == planID }) else { return }
        var template = exercises
        for e in template.indices { for s in template[e].sets.indices { template[e].sets[s].completed = false } }
        store.plans[index].exercises = template
    }
}

struct ExerciseSetRow: View {
    @Binding var set: ExerciseSet
    var body: some View {
        HStack {
            Toggle("完成", isOn: $set.completed).labelsHidden()
            if set.isChecklist == true {
                Text("完成本项活动后勾选").font(.footnote).foregroundStyle(.secondary)
            } else if set.durationSeconds != nil {
                TextField("时长", value: Binding(get: { set.durationSeconds ?? 0 }, set: { set.durationSeconds = $0 }), format: .number)
                    .keyboardType(.numberPad).frame(minWidth: 55)
                Text("秒").foregroundStyle(.secondary)
            } else {
                TextField("次数", value: $set.reps, format: .number).keyboardType(.numberPad).frame(minWidth: 35)
                Text("次").foregroundStyle(.secondary)
                TextField("重量", value: $set.weight, format: .number).keyboardType(.decimalPad).frame(minWidth: 45)
                Text("kg").foregroundStyle(.secondary)
            }
        }
    }
}
