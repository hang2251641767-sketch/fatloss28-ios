import XCTest
@testable import FitLife

final class ProgramTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var library: [TrainingProgram] = []

    override func setUpWithError() throws {
        suiteName = "FitLifeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        library = try ProgramLibrary.load()
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }
    private var original: TrainingProgram { library.first { $0.id == ProgramLibrary.originalID }! }
    private func store() -> AppStore { AppStore(defaults: defaults, programLibrary: library) }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testOfflineCatalogHasAllCategoriesAndOriginal25Items() throws {
        XCTAssertEqual(library.count, 10)
        XCTAssertEqual(Set(library.map(\.level)), ["初级", "中级"])
        XCTAssertTrue(Set(library.map(\.goal)).isSuperset(of: ["增肌", "减脂", "基础体能", "恢复"]))
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LegacyTrainingFixture", withExtension: "json"))
        let fixture = try JSONDecoder().decode([[String]].self, from: Data(contentsOf: url))
        XCTAssertEqual(original.days.map { $0.exercises.map(\.prescription) }, fixture)
        XCTAssertEqual(original.days.count, 7)
        XCTAssertEqual(original.days.flatMap(\.exercises).count, 25)
    }

    func testOldV4DataKeepsCustomPlanAndHistoryAndRecoveryIsIdempotent() throws {
        let custom = WorkoutPlan(name: "我的自定义", weekday: 3, exercises: [Exercise(name: "卧推", sets: [ExerciseSet(reps: 7, weight: 13)])])
        let history = WorkoutRecord(name: "历史训练", exercises: custom.exercises)
        let old = BackupData(profile: UserProfile(), weights: [WeightEntry(weight: 79)], nutrition: [], plans: [custom], workouts: [history])
        defaults.set(try JSONEncoder().encode(old), forKey: "fitlife.v4.data")
        let first = store()
        XCTAssertEqual(first.plans.count, 8)
        XCTAssertEqual(first.plans.first { $0.id == custom.id }?.exercises.first?.sets.first?.weight, 13)
        XCTAssertEqual(first.weights.first?.weight, 79)
        XCTAssertEqual(first.workouts.first?.id, history.id)
        XCTAssertNil(first.activeEnrollmentID, "Recovery must not override existing custom scheduling")
        let second = store()
        XCTAssertEqual(second.plans.count, 8)
        XCTAssertEqual(second.enrollments.count, 1)
        XCTAssertEqual(second.workouts.first?.id, history.id)
    }

    func testV3MigrationPreservesDatesAndRestoresRelativeSchedule() throws {
        let start = date(2026, 10, 14)
        let key = ISO8601DateFormatter().string(from: start)
        defaults.set(key, forKey: "startDate")
        defaults.set("{\"\(key)\":\"79.5\"}", forKey: "weightLog")
        let recovered = store()
        let enrollment = try XCTUnwrap(recovered.activeEnrollment)
        XCTAssertEqual(enrollment.startDate, start)
        XCTAssertEqual(recovered.weights.first?.date, start)
        XCTAssertEqual(recovered.weights.first?.weight, 79.5)
        XCTAssertEqual(recovered.scheduledPlans(on: start).first?.name, "上肢A")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        XCTAssertEqual(recovered.scheduledPlans(on: tomorrow).first?.name, "下肢A")
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        XCTAssertEqual(recovered.scheduledPlans(on: weekLater).first?.name, "上肢A")
        let finished = Calendar.current.date(byAdding: .day, value: 28, to: start)!
        XCTAssertTrue(recovered.scheduledPlans(on: finished).isEmpty)
    }

    func testEmptyExistingV4ActivatesRecoveredPlanOnlyOnce() throws {
        var profile = UserProfile()
        profile.hasCompletedOnboarding = true
        let old = BackupData(profile: profile, weights: [], nutrition: [], plans: [])
        defaults.set(try JSONEncoder().encode(old), forKey: "fitlife.v4.data")
        let first = store()
        XCTAssertEqual(first.plans.count, 7)
        XCTAssertEqual(first.activeEnrollment?.sourceID, original.id)
        let id = first.activeEnrollmentID
        first.activeEnrollmentID = nil
        let second = store()
        XCTAssertEqual(second.enrollments.count, 1)
        XCTAssertNil(second.activeEnrollmentID, "An intentional pause must survive relaunch")
        XCTAssertNotNil(id)
    }

    func testTimedAndChecklistExercisesHaveCorrectUnits() throws {
        let enrollment = original.makeEnrollment(start: date(2026, 10, 14))
        let plans = original.makePlans(for: enrollment)
        XCTAssertEqual(plans[0].exercises.last?.sets.count, 2)
        XCTAssertEqual(plans[0].exercises.last?.sets.first?.durationSeconds, 20)
        XCTAssertEqual(plans[2].exercises.first?.sets.first?.durationSeconds, 900)
        XCTAssertEqual(plans[4].exercises.last?.sets.first?.isChecklist, true)
        XCTAssertEqual(plans[1].exercises.first?.sets.count, 2)
        XCTAssertEqual(plans[1].exercises.first?.sets.first?.reps, 10)
    }

    func testSwitchingAndRestartingKeepModificationsAndHistory() throws {
        let instance = store()
        let previous = try XCTUnwrap(instance.activeEnrollmentID)
        let previousPlanIndex = try XCTUnwrap(instance.plans.firstIndex { $0.programInstanceID == previous })
        instance.plans[previousPlanIndex].exercises[0].sets[0].weight = 17
        instance.workouts.append(WorkoutRecord(name: "保留的历史"))
        let recordID = instance.workouts[0].id
        let new = try XCTUnwrap(library.first { $0.id == "hypertrophy-beginner" })
        instance.joinProgram(new, start: date(2026, 10, 14))
        XCTAssertNotEqual(instance.activeEnrollmentID, previous)
        XCTAssertEqual(instance.plans[previousPlanIndex].exercises[0].sets[0].weight, 17)
        XCTAssertEqual(instance.workouts[0].id, recordID)
        instance.restartProgram(previous, start: date(2026, 10, 15))
        XCTAssertEqual(instance.activeEnrollmentID, previous)
        XCTAssertEqual(instance.plans[previousPlanIndex].exercises[0].sets[0].weight, 17)
        XCTAssertEqual(instance.workouts[0].id, recordID)
        XCTAssertEqual(original.days[0].exercises[0].reps, 10)
        let persisted = store()
        XCTAssertEqual(persisted.enrollments.count, 2)
        XCTAssertEqual(persisted.activeEnrollmentID, previous)
        XCTAssertEqual(persisted.plans[previousPlanIndex].exercises[0].sets[0].weight, 17)
    }

    func testOldV4JSONRestoresAndNewLibraryEnrollmentRoundTrips() throws {
        let instance = store()
        let old = BackupData(profile: UserProfile(), weights: [WeightEntry(weight: 77)], nutrition: [], plans: [])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode(old).write(to: url)
        try instance.restore(from: url)
        XCTAssertEqual(instance.weights.first?.weight, 77)
        XCTAssertEqual(instance.plans.count, 7)
        let exported = try instance.exportData()
        let data = try JSONDecoder().decode(BackupData.self, from: Data(contentsOf: exported))
        XCTAssertEqual(data.enrollments?.count, 1)
        XCTAssertEqual(data.activeEnrollmentID, instance.activeEnrollmentID)
        XCTAssertEqual(data.programRecoveryVersion, 1)
        XCTAssertEqual(data.plans[0].exercises[0].prescription, original.days[0].exercises[0].prescription)
    }
}
