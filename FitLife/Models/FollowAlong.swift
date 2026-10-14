import Foundation
import Combine

enum CoachPhase: String { case warmup, prepare, exercise, rest, cooldown }
struct CoachStep: Identifiable {
    var id = UUID()
    var phase: CoachPhase
    var title: String
    var subtitle: String
    var seconds: Int
    var exerciseIndex: Int?
    var setIndex: Int?
    var side: String?
    var sidesRequired = 1
}

enum CoachBuilder {
    static func steps(exercises: [Exercise], restSeconds: Int, warmup: Int = 60, cooldown: Int = 60) -> [CoachStep] {
        var steps: [CoachStep] = []
        if warmup > 0 { steps.append(CoachStep(phase: .warmup, title: "轻松热身", subtitle: "慢速原地踏步，活动肩髋；按需要延长热身", seconds: warmup)) }
        for (e, exercise) in exercises.enumerated() {
            for (s, set) in exercise.sets.enumerated() where !set.completed {
                let text = (exercise.prescription ?? "") + (exercise.notes ?? "")
                let sides = text.contains("每侧") ? ["左侧", "右侧"] : [""]
                for side in sides {
                    steps.append(CoachStep(phase: .prepare, title: exercise.name, subtitle: "准备第 \(s + 1) 组 \(side)", seconds: 10, exerciseIndex: e, setIndex: s, side: side))
                    let duration = set.durationSeconds ?? (set.isChecklist == true ? 30 : max(1, set.reps) * 4)
                    steps.append(CoachStep(phase: .exercise, title: exercise.name,
                        subtitle: "第 \(s + 1) / \(exercise.sets.count) 组 \(side) · \(set.durationSeconds != nil ? "按时长完成" : "目标 \(set.reps) 次，按自己的节奏")",
                        seconds: max(1, duration), exerciseIndex: e, setIndex: s, side: side, sidesRequired: sides.count))
                }
                steps.append(CoachStep(phase: .rest, title: "组间休息", subtitle: "放松呼吸，准备下一组", seconds: max(1, restSeconds)))
            }
        }
        if steps.last?.phase == .rest { steps.removeLast() }
        if !steps.contains(where: { $0.phase == .exercise }) { return [] }
        if cooldown > 0 { steps.append(CoachStep(phase: .cooldown, title: "轻柔放松", subtitle: "自然呼吸，轻柔活动，不做疼痛范围的拉伸", seconds: cooldown)) }
        return steps
    }
}

/// Deadline-based countdown. Pauses freeze time; skipping never marks a set as done.
final class FollowAlongSession: ObservableObject {
    let steps: [CoachStep]
    @Published private(set) var exercises: [Exercise]
    @Published private(set) var index = 0
    @Published private(set) var remaining = 0
    @Published private(set) var paused = true
    @Published private(set) var finished = false
    private var deadline: Date?
    private var sidesDone: [UUID: Set<String>] = [:]
    init(exercises: [Exercise], restSeconds: Int, warmup: Int = 60, cooldown: Int = 60) {
        self.exercises = exercises
        steps = CoachBuilder.steps(exercises: exercises, restSeconds: restSeconds, warmup: warmup, cooldown: cooldown)
        remaining = steps.first?.seconds ?? 0
        finished = steps.isEmpty
    }
    var current: CoachStep? { finished || !steps.indices.contains(index) ? nil : steps[index] }
    var progress: Double { steps.isEmpty ? 1 : Double(index) / Double(steps.count) }
    var completedSets: Int { exercises.flatMap(\.sets).filter(\.completed).count }
    var estimatedSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }
    func resume(now: Date = Date()) { guard !finished else { return }; paused = false; deadline = now.addingTimeInterval(TimeInterval(remaining)) }
    func pause(now: Date = Date()) {
        if let deadline = deadline, !paused { remaining = max(0, Int(ceil(deadline.timeIntervalSince(now)))) }
        paused = true; deadline = nil
    }
    func tick(now: Date = Date()) {
        guard !paused, !finished, let deadline = deadline else { return }
        remaining = max(0, Int(ceil(deadline.timeIntervalSince(now))))
        if remaining == 0 { advance(completed: true, now: now) }
    }
    func skip(now: Date = Date()) { advance(completed: false, now: now) }
    func finishCurrent(now: Date = Date()) { advance(completed: true, now: now) }
    func previous(now: Date = Date()) {
        guard !steps.isEmpty else { return }
        // Replaying a set does not clear already earned completion.
        finished = false; index = max(0, index - 1); remaining = steps[index].seconds
        deadline = paused ? nil : now.addingTimeInterval(TimeInterval(remaining))
    }
    private func advance(completed: Bool, now: Date) {
        guard !finished, let step = current else { return }
        if completed, step.phase == .exercise, let e = step.exerciseIndex, let s = step.setIndex {
            let id = exercises[e].sets[s].id
            sidesDone[id, default: []].insert(step.side ?? "")
            if sidesDone[id, default: []].count >= step.sidesRequired { exercises[e].sets[s].completed = true }
        }
        index += 1
        if index >= steps.count { finished = true; paused = true; deadline = nil; remaining = 0 }
        else { remaining = steps[index].seconds; deadline = paused ? nil : now.addingTimeInterval(TimeInterval(remaining)) }
    }
}
