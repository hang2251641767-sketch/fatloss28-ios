import Foundation

struct UserProfile: Codable {
    var name = ""
    var height: Double = 170
    var targetWeight: Double = 60
    var dailyCalories = 1800
    var reminderEnabled = false
    var reminderHour = 20
    var hasCompletedOnboarding = false
}

struct WeightEntry: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var weight: Double
    var note = ""
}

struct NutritionEntry: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var meal = ""
    var guideMealID: String?
}

struct Exercise: Codable, Identifiable {
    var id = UUID()
    var name: String
    var sets: [ExerciseSet] = []
    var prescription: String?
    var notes: String?
}

struct ExerciseSet: Codable, Identifiable {
    var id = UUID()
    var reps: Int = 10
    var weight: Double = 0
    var completed = false
    var durationSeconds: Int?
    var isChecklist: Bool?
}

struct WorkoutPlan: Codable, Identifiable {
    var id = UUID()
    var name: String
    var weekday: Int
    var exercises: [Exercise] = []
    var isCompleted = false
    var completedDate: Date?
    var programInstanceID: UUID?
    var cycleDay: Int?
    var instructions: String?
    var restSeconds: Int?
}

struct WorkoutRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var planID: UUID?
    var name: String
    var exercises: [Exercise] = []
}

/// Optional fields allow the original V4 backup format to remain readable.
struct BackupData: Codable {
    var version = 4
    var profile: UserProfile
    var weights: [WeightEntry]
    var nutrition: [NutritionEntry]
    var plans: [WorkoutPlan]
    var workouts: [WorkoutRecord]?
    var legacyV3: [String: String]?
    var enrollments: [ProgramEnrollment]?
    var activeEnrollmentID: UUID?
    var programRecoveryVersion: Int?
    var nutritionPreferences: NutritionPreferences?
}

enum DataError: LocalizedError {
    case invalidBackup
    var errorDescription: String? {
        "备份格式或数值无效。请选择 FitLife 的 JSON 备份。"
    }
}

enum NumberInput {
    static func decimal(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: ".").replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
