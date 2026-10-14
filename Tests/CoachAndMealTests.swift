import XCTest
@testable import FitLife

final class CoachAndMealTests: XCTestCase {
    func testBenchPressNeverMatchesPlankAndUnsupportedEquipmentIsExplicit() {
        XCTAssertEqual(ExerciseGuide.forName("哑铃平板卧推").movement, .chestPress)
        XCTAssertEqual(ExerciseGuide.forName("上斜哑铃卧推").movement, .chestPress)
        XCTAssertEqual(ExerciseGuide.forName("平板支撑").movement, .plank)
        XCTAssertEqual(ExerciseGuide.forName("侧平板支撑").movement, .sidePlank)
        XCTAssertEqual(ExerciseGuide.forName("墙壁俯卧撑").movement, .wallPushup)
        XCTAssertEqual(ExerciseGuide.forName("腿举").movement, .custom)
    }
    func testPausedTimeFreezesAndDoesNotCreditBackgroundTime() {
        let exercise = Exercise(name: "深蹲", sets: [ExerciseSet(reps: 2)])
        let session = FollowAlongSession(exercises: [exercise], restSeconds: 5, warmup: 0, cooldown: 0)
        let start = Date(timeIntervalSince1970: 1_000)
        session.resume(now: start)
        session.tick(now: start.addingTimeInterval(4))
        XCTAssertEqual(session.remaining, 6)
        session.pause(now: start.addingTimeInterval(4))
        session.tick(now: start.addingTimeInterval(100))
        XCTAssertEqual(session.remaining, 6)
        XCTAssertEqual(session.completedSets, 0)
        session.resume(now: start.addingTimeInterval(100))
        session.tick(now: start.addingTimeInterval(106))
        XCTAssertEqual(session.current?.phase, .exercise)
        XCTAssertEqual(session.remaining, 8)
    }
    func testSkippingDoesNotCompleteASet() {
        let exercise = Exercise(name: "深蹲", sets: [ExerciseSet(reps: 2)])
        let session = FollowAlongSession(exercises: [exercise], restSeconds: 5, warmup: 0, cooldown: 0)
        session.skip() // prepare
        session.skip() // exercise
        XCTAssertTrue(session.finished)
        XCTAssertEqual(session.completedSets, 0)
    }
    func testUnilateralSetRequiresBothSidesAndCanFinishManually() {
        let exercise = Exercise(name: "单臂划船", sets: [ExerciseSet(reps: 2)], prescription: "2次，每侧")
        let session = FollowAlongSession(exercises: [exercise], restSeconds: 5, warmup: 0, cooldown: 0)
        session.skip(); XCTAssertEqual(session.current?.side, "左侧")
        session.finishCurrent(); XCTAssertEqual(session.completedSets, 0)
        session.skip(); XCTAssertEqual(session.current?.side, "右侧")
        session.finishCurrent()
        XCTAssertTrue(session.finished)
        XCTAssertEqual(session.completedSets, 1)
    }
    func testCompletedSetsAreNotRepeatedAndNoEmptyWorkoutIsGenerated() {
        let exercise = Exercise(name: "臀桥", sets: [ExerciseSet(completed: true)])
        let session = FollowAlongSession(exercises: [exercise], restSeconds: 90)
        XCTAssertTrue(session.finished)
        XCTAssertTrue(session.steps.isEmpty)
        let empty = FollowAlongSession(exercises: [], restSeconds: 90)
        XCTAssertTrue(empty.finished)
    }
    func testTimeoutFinishesOnlyOneStepInsteadOfImaginingWholeWorkout() {
        let exercise = Exercise(name: "深蹲", sets: [ExerciseSet(reps: 2)])
        let session = FollowAlongSession(exercises: [exercise], restSeconds: 5, warmup: 0, cooldown: 0)
        let start = Date(timeIntervalSince1970: 1_000)
        session.resume(now: start)
        session.tick(now: start.addingTimeInterval(1_000))
        XCTAssertEqual(session.index, 1)
        XCTAssertEqual(session.completedSets, 0)
    }
    func testMealGuideHasSevenDaysFourMealsAndExplicitWeights() throws {
        let days = try MealGuide.load()
        XCTAssertEqual(days.count, 7)
        for day in days {
            XCTAssertEqual(day.meals.count, 4)
            XCTAssertTrue((1700...2200).contains(day.calories))
            for ingredient in day.meals.flatMap(\.ingredients) {
                XCTAssertGreaterThan(ingredient.grams, 0)
                XCTAssertFalse(ingredient.basis.isEmpty)
            }
        }
    }
    func testAllergensBlockMealLoggingAndDuplicateMealsAreNotAdded() throws {
        let name = "CoachMealTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AppStore(defaults: defaults, programLibrary: try ProgramLibrary.load())
        let meal = try XCTUnwrap(MealGuide.load().first?.meals.first)
        store.nutritionPreferences.allergens = ["乳制品"]
        XCTAssertTrue(meal.isBlocked(store.nutritionPreferences))
        XCTAssertFalse(store.logSuggestedMeal(meal, on: Date()))
        store.nutritionPreferences.allergens = []
        XCTAssertTrue(store.logSuggestedMeal(meal, on: Date()))
        XCTAssertFalse(store.logSuggestedMeal(meal, on: Date()))
        XCTAssertEqual(store.nutrition.count, 1)
        XCTAssertEqual(store.nutrition.first?.calories, meal.calories)
        XCTAssertEqual(AppStore(defaults: defaults).nutrition.count, 1)
    }
    func testAvoidedFoodsAndMealCycleRespectCourseStart() throws {
        let meal = try XCTUnwrap(MealGuide.load().first?.meals[1])
        var preference = NutritionPreferences()
        preference.avoidedFoods = "牛肉，鸡胸肉"
        XCTAssertTrue(meal.isBlocked(preference))
        let start = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(MealGuide.dayIndex(on: start, courseStart: start), 0)
        let next = Calendar.current.date(byAdding: .day, value: 8, to: start)!
        XCTAssertEqual(MealGuide.dayIndex(on: next, courseStart: start), 1)
    }
    func testOlderBackupsDecodeNewPreferencesAsOptional() throws {
        let old = BackupData(profile: UserProfile(), weights: [], nutrition: [], plans: [])
        let data = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(BackupData.self, from: data)
        XCTAssertNil(decoded.nutritionPreferences)
    }
}
