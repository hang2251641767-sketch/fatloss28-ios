import Foundation
import Combine
import UserNotifications

final class AppStore: ObservableObject {
    @Published var profile = UserProfile() { didSet { save() } }
    @Published var weights: [WeightEntry] = [] { didSet { save() } }
    @Published var nutrition: [NutritionEntry] = [] { didSet { save() } }
    @Published var plans: [WorkoutPlan] = [] { didSet { save() } }
    @Published var workouts: [WorkoutRecord] = [] { didSet { save() } }
    @Published var enrollments: [ProgramEnrollment] = [] { didSet { save() } }
    @Published var activeEnrollmentID: UUID? { didSet { save() } }
    @Published private(set) var library: [TrainingProgram] = []
    @Published private(set) var libraryError = ""
    private var programRecoveryVersion: Int?
    @Published var reminderMessage = ""
    private var legacyV3: [String: String] = [:]
    private let defaults: UserDefaults
    private let key = "fitlife.v4.data"
    private var loading = true
    private var unreadableData = false

    init(defaults: UserDefaults = .standard, programLibrary: [TrainingProgram]? = nil) {
        self.defaults = defaults
        if let provided = programLibrary { library = provided }
        else {
            do { library = try ProgramLibrary.load() }
            catch { libraryError = "本地计划库读取失败：\(error.localizedDescription)" }
        }
        if let data = defaults.data(forKey: key),
           let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
            apply(backup)
        } else if defaults.data(forKey: key) == nil {
            migrateV3()
        } else {
            unreadableData = true
        }
        if !unreadableData { recoverOriginalProgramIfNeeded() }
        loading = false
        save()
    }

    var activeEnrollment: ProgramEnrollment? { enrollments.first { $0.id == activeEnrollmentID } }
    func plansForEnrollment(_ id: UUID) -> [WorkoutPlan] { plans.filter { $0.programInstanceID == id } }
    func scheduledPlans(on date: Date) -> [WorkoutPlan] {
        plans.filter { ProgramSchedule.matches($0, date: date, enrollments: enrollments, activeID: activeEnrollmentID) }
    }

    var latestWeight: WeightEntry? { weights.max { $0.date < $1.date } }
    var todayNutrition: [NutritionEntry] { nutrition.filter { Calendar.current.isDateInToday($0.date) } }
    var todayCalories: Int { todayNutrition.reduce(0) { $0 + $1.calories } }
    var todayPlans: [WorkoutPlan] { scheduledPlans(on: Date()) }
    var streak: Int {
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: Date())
        let dates = Set(weights.map { calendar.startOfDay(for: $0.date) } + workouts.map { calendar.startOfDay(for: $0.date) })
        if !dates.contains(date) { date = calendar.date(byAdding: .day, value: -1, to: date)! }
        var count = 0
        while dates.contains(date) {
            count += 1
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    func addWeight(_ value: Double, on date: Date = Date()) {
        guard value.isFinite, (20...500).contains(value) else { return }
        if let index = weights.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            weights[index].weight = value
        } else {
            weights.append(WeightEntry(date: date, weight: value))
        }
    }

    func completeWorkout(_ plan: WorkoutPlan, exercises: [Exercise]) {
        guard exercises.contains(where: { $0.sets.contains(where: { $0.completed }) }) else { return }
        let record = WorkoutRecord(planID: plan.id, name: plan.name, exercises: exercises)
        if let index = workouts.firstIndex(where: { $0.planID == plan.id && Calendar.current.isDateInToday($0.date) }) {
            workouts[index] = record
        } else {
            workouts.append(record)
        }
    }

    private var backup: BackupData {
        BackupData(profile: profile, weights: weights, nutrition: nutrition, plans: plans,
                   workouts: workouts, legacyV3: legacyV3, enrollments: enrollments,
                   activeEnrollmentID: activeEnrollmentID, programRecoveryVersion: programRecoveryVersion)
    }

    func save() {
        guard !loading, !unreadableData, let data = try? JSONEncoder().encode(backup) else { return }
        defaults.set(data, forKey: key)
    }

    private func apply(_ data: BackupData) {
        profile = data.profile
        weights = data.weights
        nutrition = data.nutrition
        plans = data.plans
        workouts = data.workouts ?? []
        legacyV3 = data.legacyV3 ?? [:]
        enrollments = data.enrollments ?? []
        activeEnrollmentID = data.activeEnrollmentID
        programRecoveryVersion = data.programRecoveryVersion
    }

    func exportData() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FitLife-备份-\(formatter.string(from: Date())).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(backup).write(to: url, options: .atomic)
        return url
    }

    func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard data.count < 25_000_000 else { throw DataError.invalidBackup }
        let restored = try JSONDecoder().decode(BackupData.self, from: data)
        guard restored.version == 4,
              restored.profile.targetWeight.isFinite, (20...500).contains(restored.profile.targetWeight),
              (80...260).contains(restored.profile.height), (800...5000).contains(restored.profile.dailyCalories),
              (0...23).contains(restored.profile.reminderHour),
              restored.weights.allSatisfy({ $0.weight.isFinite && (20...500).contains($0.weight) }),
              Set(restored.weights.map(\.id)).count == restored.weights.count,
              Set(restored.plans.map(\.id)).count == restored.plans.count,
              Set(restored.nutrition.map(\.id)).count == restored.nutrition.count,
              Set((restored.workouts ?? []).map(\.id)).count == (restored.workouts ?? []).count,
              restored.plans.allSatisfy({ (1...7).contains($0.weekday) && ($0.cycleDay.map { (0...6).contains($0) } ?? true) }),
              Set((restored.enrollments ?? []).map(\.id)).count == (restored.enrollments ?? []).count,
              (restored.enrollments ?? []).allSatisfy({ (1...52).contains($0.weeks) }),
              restored.activeEnrollmentID.map({ id in (restored.enrollments ?? []).contains { $0.id == id } }) ?? true,
              restored.plans.allSatisfy({ plan in plan.programInstanceID.map { id in (restored.enrollments ?? []).contains { $0.id == id } } ?? true }),
              restored.nutrition.allSatisfy({ $0.calories >= 0 && $0.calories <= 20000 && $0.protein.isFinite && $0.carbs.isFinite && $0.fat.isFinite && $0.protein >= 0 && $0.carbs >= 0 && $0.fat >= 0 })
        else { throw DataError.invalidBackup }
        // Keep a recovery copy before replacing data.
        defaults.set(defaults.data(forKey: key), forKey: "fitlife.v4.beforeRestore")
        loading = true
        apply(restored)
        unreadableData = false
        recoverOriginalProgramIfNeeded()
        loading = false
        save()
        updateReminder()
    }

    func updateReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["fitlife.reminder", "daily-training"])
        guard profile.reminderEnabled else { reminderMessage = "提醒已关闭"; return }
        let hour = profile.reminderHour
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard granted, error == nil else {
                    self.reminderMessage = "请到系统设置中为 FitLife 开启通知权限。"
                    return
                }
                guard self.profile.reminderEnabled, self.profile.reminderHour == hour else { return }
                let content = UNMutableNotificationContent()
                content.title = "FitLife · 今日打卡"
                content.body = "记录体重、饮食和训练，保持你的节奏。"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
                center.add(UNNotificationRequest(identifier: "fitlife.reminder", content: content, trigger: trigger)) { error in
                    DispatchQueue.main.async {
                        self.reminderMessage = error?.localizedDescription ?? "已设置每日提醒"
                    }
                }
            }
        }
    }

    /// Each enrollment owns copies, so editing it cannot mutate the offline library.
    func joinProgram(_ program: TrainingProgram, start: Date) {
        let enrollment = program.makeEnrollment(start: start)
        loading = true
        enrollments.append(enrollment)
        plans.append(contentsOf: program.makePlans(for: enrollment))
        activeEnrollmentID = enrollment.id
        loading = false
        save()
    }

    /// A new cycle preserves modified templates and historical workout snapshots.
    func restartProgram(_ id: UUID, start: Date = Date()) {
        guard let index = enrollments.firstIndex(where: { $0.id == id }) else { return }
        loading = true
        enrollments[index].startDate = Calendar.current.startOfDay(for: start)
        for p in plans.indices where plans[p].programInstanceID == id {
            let date = Calendar.current.date(byAdding: .day, value: plans[p].cycleDay ?? 0, to: enrollments[index].startDate) ?? start
            plans[p].weekday = Calendar.current.component(.weekday, from: date)
        }
        activeEnrollmentID = id
        loading = false
        save()
    }

    private func recoverOriginalProgramIfNeeded() {
        guard programRecoveryVersion == nil,
              let original = library.first(where: { $0.id == ProgramLibrary.originalID }) else { return }
        if let existing = enrollments.first(where: { $0.sourceID == original.id }) {
            // Do not change an already selected program or any exercise modifications.
            if activeEnrollmentID == nil && enrollments.count == 1 { activeEnrollmentID = existing.id }
            programRecoveryVersion = 1
            return
        }
        let previousHadPlans = !plans.isEmpty || !enrollments.isEmpty
        let legacyStart = legacyV3["startDate"] ?? defaults.string(forKey: "startDate")
        let start = legacyStart.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        let enrollment = original.makeEnrollment(start: start)
        enrollments.append(enrollment)
        plans.append(contentsOf: original.makePlans(for: enrollment))
        if !previousHadPlans { activeEnrollmentID = enrollment.id }
        programRecoveryVersion = 1
    }

    private func migrateV3() {
        for oldKey in ["startDate", "weightLog", "waistLog", "doneItems"] {
            if let value = defaults.string(forKey: oldKey) { legacyV3[oldKey] = value }
        }
        let iso = ISO8601DateFormatter()
        if let text = legacyV3["weightLog"],
           let log = try? JSONDecoder().decode([String: String].self, from: Data(text.utf8)) {
            weights = log.compactMap { key, text in
                guard let date = iso.date(from: key), let weight = NumberInput.decimal(text), (20...500).contains(weight) else { return nil }
                return WeightEntry(date: date, weight: weight, note: "从 V3 迁移")
            }.sorted { $0.date < $1.date }
        }
        if let text = legacyV3["doneItems"],
           let log = try? JSONDecoder().decode([String: [String: Bool]].self, from: Data(text.utf8)) {
            workouts = log.compactMap { key, items in
                guard let date = iso.date(from: key), items.values.contains(true) else { return nil }
                let exercises = items.filter { $0.value }.keys.sorted().map { Exercise(name: $0, sets: [ExerciseSet(completed: true)]) }
                return WorkoutRecord(date: date, name: "V3 已打卡项目", exercises: exercises)
            }.sorted { $0.date < $1.date }
        }
        // Older variants may use an array instead of the published V3 JSON strings.
        if weights.isEmpty, let old = defaults.array(forKey: "weightRecords") as? [[String: Any]] {
            weights = old.compactMap { item in
                guard let weight = item["weight"] as? Double, (20...500).contains(weight) else { return nil }
                let date = (item["date"] as? Date) ?? (item["date"] as? String).flatMap { iso.date(from: $0) } ?? Date()
                return WeightEntry(date: date, weight: weight, note: "从旧版迁移")
            }
        }
        // Original V3 keys remain untouched; the raw waist/start/check-in data is also exported.
    }
}
