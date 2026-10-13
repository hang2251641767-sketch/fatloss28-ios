import Foundation

enum ProgramLibrary {
    static let originalID = "legacy-v3-28day"
    static func load(bundle: Bundle = .main) throws -> [TrainingProgram] {
        guard let url = bundle.url(forResource: "TrainingPrograms", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }
    static func load(from url: URL) throws -> [TrainingProgram] {
        let programs = try JSONDecoder().decode([TrainingProgram].self, from: Data(contentsOf: url))
        guard !programs.isEmpty, Set(programs.map(\.id)).count == programs.count,
              programs.contains(where: { $0.id == originalID }),
              programs.allSatisfy({ program in
                  program.weeks > 0 && !program.days.isEmpty &&
                  Set(program.days.map(\.offset)).count == program.days.count &&
                  program.days.allSatisfy { day in
                      (0...6).contains(day.offset) && day.restSeconds > 0 && !day.exercises.isEmpty &&
                      day.exercises.allSatisfy { exercise in
                          exercise.sets > 0 && !exercise.name.isEmpty &&
                          ((exercise.reps ?? 0) > 0 || (exercise.durationSeconds ?? 0) > 0)
                      }
                  }
              }) else { throw DataError.invalidBackup }
        return programs
    }
}
