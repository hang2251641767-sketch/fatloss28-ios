import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var store: AppStore
    @State private var creating = false
    private let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("计划每周循环使用。完成训练会独立保存当天组次和重量，不会覆盖历史。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.plans) { plan in
                    NavigationLink {
                        WorkoutDetailView(planID: plan.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name).font(.headline)
                            Text("\(weekdays[plan.weekday - 1]) · \(plan.exercises.count) 个动作")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.onDelete { store.plans.remove(atOffsets: $0) }
            }
            .overlay {
                if store.plans.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "dumbbell").font(.largeTitle).foregroundStyle(.green)
                        Text("还没有训练计划").font(.headline)
                        Button("新建循环计划") { creating = true }
                    }
                }
            }
            .navigationTitle("训练")
            .toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $creating) { PlanEditorView() }
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
                Picker("每周训练日", selection: $day) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(["周日", "周一", "周二", "周三", "周四", "周五", "周六"][weekday - 1]).tag(weekday)
                    }
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
                if let plan = store.plans.first(where: { $0.id == existingID }) {
                    name = plan.name; day = plan.weekday
                }
            }
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var store: AppStore
    let planID: UUID
    @State private var exercises: [Exercise] = []
    @State private var exerciseName = ""
    @State private var editing = false
    @State private var message = ""
    @State private var showingMessage = false
    var plan: WorkoutPlan? { store.plans.first { $0.id == planID } }

    var body: some View {
        List {
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
                    ForEach($exercise.sets) { $set in
                        HStack {
                            Toggle("完成", isOn: $set.completed).labelsHidden()
                            TextField("次数", value: $set.reps, format: .number)
                                .keyboardType(.numberPad).frame(minWidth: 35)
                            Text("次").foregroundStyle(.secondary)
                            TextField("重量", value: $set.weight, format: .number)
                                .keyboardType(.decimalPad).frame(minWidth: 45)
                            Text("kg").foregroundStyle(.secondary)
                        }
                    }.onDelete { exercise.sets.remove(atOffsets: $0) }
                    Button("增加一组") { exercise.sets.append(ExerciseSet()) }
                    Button("删除动作", role: .destructive) { exercises.removeAll { $0.id == exercise.id } }
                }
            }
            Section("组间休息") { RestTimerView() }
            Section {
                Button("保存动作到循环计划") { saveTemplate() }
                Button("完成今日训练") {
                    guard let plan = plan else { return }
                    guard validExercises else { message = "请检查次数和重量"; showingMessage = true; return }
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
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .navigationTitle(plan?.name ?? "训练")
        .toolbar { Button("编辑计划") { editing = true } }
        .sheet(isPresented: $editing) { PlanEditorView(existingID: planID) }
        .onAppear {
            if exercises.isEmpty {
                exercises = store.workouts.first(where: { $0.planID == planID && Calendar.current.isDateInToday($0.date) })?.exercises ?? plan?.exercises ?? []
            }
        }
        .alert("训练", isPresented: $showingMessage) { Button("好", role: .cancel) {} } message: { Text(message) }
    }

    private var validExercises: Bool {
        exercises.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.sets.allSatisfy { $0.reps > 0 && $0.reps <= 10000 && $0.weight.isFinite && (0...2000).contains($0.weight) } }
    }
    private func saveTemplate() {
        guard validExercises, let index = store.plans.firstIndex(where: { $0.id == planID }) else { return }
        var template = exercises
        for e in template.indices {
            for s in template[e].sets.indices { template[e].sets[s].completed = false }
        }
        store.plans[index].exercises = template
    }
}
