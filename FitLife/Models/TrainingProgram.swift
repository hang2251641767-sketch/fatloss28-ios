import Foundation

struct TrainingProgram: Codable, Identifiable {
    var id: String
    var name: String
    var level: String
    var goal: String
    var equipment: String
    var weeks: Int
    var minutes: String
    var summary: String
    var guidance: String
    var progression: String
    var source: String
    var days: [ProgramDay]
    var isOriginal: Bool { id == "legacy-v3-28day" }

    func makeEnrollment(start: Date) -> ProgramEnrollment {
        ProgramEnrollment(sourceID: id, name: name, startDate: Calendar.current.startOfDay(for: start),
                          weeks: weeks, guidance: guidance, progression: progression)
    }
    func makePlans(for enrollment: ProgramEnrollment) -> [WorkoutPlan] {
        days.map { day in
            let date = Calendar.current.date(byAdding: .day, value: day.offset, to: enrollment.startDate) ?? enrollment.startDate
            return WorkoutPlan(name: day.name, weekday: Calendar.current.component(.weekday, from: date),
                exercises: day.exercises.map { item in
                    Exercise(name: item.name, sets: (0..<item.sets).map { _ in
                        ExerciseSet(reps: item.reps ?? 1, durationSeconds: item.durationSeconds, isChecklist: item.checklist)
                    }, prescription: item.prescription, notes: item.notes)
                },
                programInstanceID: enrollment.id, cycleDay: day.offset,
                instructions: day.instructions, restSeconds: day.restSeconds)
        }
    }
}

struct ProgramDay: Codable, Identifiable {
    var offset: Int
    var name: String
    var instructions: String
    var restSeconds: Int
    var exercises: [ProgramExercise]
    var id: Int { offset }
}
struct ProgramExercise: Codable {
    var name: String
    var prescription: String
    var sets: Int
    var reps: Int?
    var durationSeconds: Int?
    var notes: String?
    var checklist: Bool?
}

struct ProgramEnrollment: Codable, Identifiable {
    var id = UUID()
    var sourceID: String
    var name: String
    var startDate: Date
    var weeks: Int
    var guidance: String
    var progression: String

    func dayOffset(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                to: calendar.startOfDay(for: date)).day ?? -1
    }
    func isInRange(on date: Date) -> Bool {
        let offset = dayOffset(on: date)
        return offset >= 0 && offset < weeks * 7
    }
    func week(on date: Date) -> Int { min(weeks, max(1, dayOffset(on: date) / 7 + 1)) }
    func progress(on date: Date) -> Double { min(1, max(0, Double(dayOffset(on: date) + 1) / Double(weeks * 7))) }
    var endDate: Date { Calendar.current.date(byAdding: .day, value: weeks * 7 - 1, to: startDate) ?? startDate }
}

/// Schedules program days relative to the start date, not an assumed Monday.
enum ProgramSchedule {
    static func matches(_ plan: WorkoutPlan, date: Date, enrollments: [ProgramEnrollment], activeID: UUID?) -> Bool {
        if let instanceID = plan.programInstanceID {
            guard instanceID == activeID,
                  let enrollment = enrollments.first(where: { $0.id == instanceID }),
                  enrollment.isInRange(on: date), let day = plan.cycleDay else { return false }
            return enrollment.dayOffset(on: date) % 7 == day
        }
        return plan.weekday == Calendar.current.component(.weekday, from: date)
    }
}
