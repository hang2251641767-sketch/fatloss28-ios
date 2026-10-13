import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedDate = Date()
    @State private var addingWeight = false
    private var dayWeights: [WeightEntry] { store.weights.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    private var dayWorkouts: [WorkoutRecord] { store.workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("选择日期", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                Section("所选日期") {
                    ForEach(store.scheduledPlans(on: selectedDate)) { plan in
                        Text("计划安排：\(plan.name)").font(.footnote).foregroundStyle(.secondary)
                    }
                    if dayWeights.isEmpty { Text("尚未记录体重").foregroundStyle(.secondary) }
                    ForEach(dayWeights) { entry in Text(String(format: "体重：%.1f kg", entry.weight)).bold() }
                    Button("记录 / 修改当天体重") { addingWeight = true }
                    if dayWorkouts.isEmpty { Text("当天暂无训练打卡").foregroundStyle(.secondary) }
                    ForEach(dayWorkouts) { workout in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(workout.name, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            ForEach(workout.exercises) { exercise in
                                Text("\(exercise.name)：\(exercise.sets.filter { $0.completed }.count) 组已完成")
                                    .font(.footnote)
                            }
                        }
                    }
                }
                Section("历史体重") {
                    ForEach(store.weights.sorted { $0.date > $1.date }) { entry in
                        HStack { Text(entry.date, style: .date); Spacer(); Text(String(format: "%.1f kg", entry.weight)).bold() }
                    }.onDelete { offsets in
                        let displayed = store.weights.sorted { $0.date > $1.date }
                        let ids = offsets.map { displayed[$0].id }
                        store.weights.removeAll { ids.contains($0.id) }
                    }
                }
                Section("历史训练") {
                    ForEach(store.workouts.sorted { $0.date > $1.date }) { workout in
                        NavigationLink {
                            List {
                                ForEach(workout.exercises) { exercise in
                                    Section(exercise.name) {
                                        ForEach(exercise.sets) { set in
                                            if set.isChecklist == true {
                                                Text(set.completed ? "✓ 已完成活动" : "○ 未完成活动")
                                            } else if let seconds = set.durationSeconds {
                                                Text("\(set.completed ? "✓" : "○") \(seconds) 秒")
                                            } else {
                                                Text("\(set.completed ? "✓" : "○") \(set.reps) 次 · \(set.weight, specifier: "%.1f") kg")
                                            }
                                        }
                                    }
                                }
                            }.navigationTitle(workout.name)
                        } label: {
                            VStack(alignment: .leading) { Text(workout.name); Text(workout.date, style: .date).font(.caption).foregroundStyle(.secondary) }
                        }
                    }.onDelete { offsets in
                        let displayed = store.workouts.sorted { $0.date > $1.date }
                        let ids = offsets.map { displayed[$0].id }
                        store.workouts.removeAll { ids.contains($0.id) }
                    }
                }
            }.navigationTitle("日历")
                .sheet(isPresented: $addingWeight) { WeightEntryView(initialDate: selectedDate) }
        }
    }
}
