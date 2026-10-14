import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var store: AppStore
    @State private var creating = false
    @State private var deleting: UUID?
    @State private var deletePrompt = false
    private var customPlans: [WorkoutPlan] { store.plans.filter { $0.programInstanceID == nil } }
    private var subscriptions: [ProgramEnrollment] {
        store.enrollments.sorted {
            if ($0.id == store.activeEnrollmentID) != ($1.id == store.activeEnrollmentID) { return $0.id == store.activeEnrollmentID }
            return $0.startDate > $1.startDate
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("我订阅的课程").font(.title2.bold())
                            Text("每天一步，跟着自己的节奏完成").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        NavigationLink { ProgramLibraryView() } label: { Image(systemName: "square.grid.2x2.fill").font(.title2) }
                    }
                    if subscriptions.isEmpty {
                        NavigationLink { ProgramLibraryView() } label: {
                            CourseCard(title: "28天居家减脂", subtitle: "哑铃与自重 · 从基础开始", image: "CourseHome", badge: "选择你的第一门课程")
                        }.buttonStyle(SpringCardStyle())
                    }
                    ForEach(subscriptions) { enrollment in
                        NavigationLink { EnrollmentDetailView(enrollmentID: enrollment.id) } label: {
                            CourseCard(title: enrollment.sourceID == ProgramLibrary.originalID ? "28天居家减脂" : enrollment.name,
                                subtitle: "\(enrollment.weeks) 周课程 · \(enrollment.id == store.activeEnrollmentID ? "正在跟练" : "已订阅，可随时启用")",
                                image: store.library.first { $0.id == enrollment.sourceID }?.coverName ?? "CourseHome",
                                badge: enrollment.id == store.activeEnrollmentID ? "我的当前课程" : "已订阅",
                                progress: enrollment.progress(on: Date()))
                        }.buttonStyle(SpringCardStyle())
                    }
                    if !store.todayPlans.isEmpty {
                        Text("今日跟练").font(.title3.bold())
                        ForEach(store.todayPlans) { plan in
                            NavigationLink { WorkoutDetailView(planID: plan.id) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(plan.name).font(.headline).foregroundStyle(.primary)
                                        Text("\(plan.exercises.count) 个动作 / 活动 · 进入后点开始跟练").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }.padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(SpringCardStyle())
                        }
                    }
                    NavigationLink { ProgramLibraryView() } label: {
                        Label("探索课程库 · 初级 / 中级 / 增肌 / 减脂", systemImage: "sparkles")
                            .font(.headline).frame(maxWidth: .infinity).padding()
                            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    }
                    Text("我的自定义训练").font(.title3.bold())
                    ForEach(customPlans) { plan in
                        NavigationLink { WorkoutDetailView(planID: plan.id) } label: {
                            HStack {
                                Label(plan.name, systemImage: "dumbbell.fill").foregroundStyle(.primary)
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .contextMenu { Button("删除此计划", role: .destructive) { deleting = plan.id; deletePrompt = true } }
                    }
                    Button("创建自定义训练") { creating = true }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    Text("订阅表示加入本机课程，无需登录或付费。切换课程会保留以前的动作修改和历史。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("训练")
            .toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $creating) { PlanEditorView() }
            .confirmationDialog("删除自定义计划？历史记录会保留", isPresented: $deletePrompt, titleVisibility: .visible) {
                Button("删除", role: .destructive) { if let id = deleting { store.plans.removeAll { $0.id == id } } }
            }
        }
    }
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
                Section(enrollment.sourceID == ProgramLibrary.originalID ? "28天居家减脂" : enrollment.name) {
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
        .navigationTitle("我订阅的课程")
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
    @State private var coachLaunch: CoachLaunch?
    var plan: WorkoutPlan? { store.plans.first { $0.id == planID } }

    var body: some View {
        List {
            Section {
                Button {
                    guard let current = plan, validExercises else { message = "请先检查动作与组次"; showingMessage = true; return }
                    coachLaunch = CoachLaunch(plan: current, exercises: exercises)
                } label: {
                    Label("开始动画跟练", systemImage: "play.circle.fill").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).disabled(exercises.isEmpty || exercises.allSatisfy { $0.sets.allSatisfy(\.completed) })
                Text("中文语音、动作示意、倒计时；已完成的组会跳过。").font(.footnote).foregroundStyle(.secondary)
            }
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
        .fullScreenCover(item: $coachLaunch, onDismiss: {
            if let recorded = store.workouts.first(where: { $0.planID == planID && Calendar.current.isDateInToday($0.date) }) {
                exercises = recorded.exercises
            }
        }) { launch in FollowAlongView(plan: launch.plan, exercises: launch.exercises) }
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
