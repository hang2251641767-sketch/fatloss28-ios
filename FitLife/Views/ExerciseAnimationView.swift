import SwiftUI

/// Code-native schematic motion, not a filmed coach or a form assessment.
struct ExerciseAnimationView: View {
    let name: String
    let paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if ExerciseGuide.forName(name).movement == .custom {
            VStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 70)).foregroundStyle(.mint)
                Text("此动作暂无对应动画，请按文字要点完成").font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
        } else {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { context in
            let amount = reduceMotion ? 0.25 : (sin(context.date.timeIntervalSinceReferenceDate * .pi / 2) + 1) / 2
            Canvas { canvas, size in
                let pose = joints(ExerciseGuide.forName(name).movement, amount)
                func point(_ pair: (Double, Double)) -> CGPoint { CGPoint(x: pair.0 * size.width, y: pair.1 * size.height) }
                let links = [(1,2),(1,3),(3,4),(1,5),(5,6),(2,7),(7,8),(2,9),(9,10)]
                for (a, b) in links {
                    var path = Path(); path.move(to: point(pose[a])); path.addLine(to: point(pose[b]))
                    canvas.stroke(path, with: .color(a == 1 || a == 2 ? .mint : .white.opacity(0.8)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                }
                let head = point(pose[0])
                canvas.fill(Path(ellipseIn: CGRect(x: head.x - 13, y: head.y - 13, width: 26, height: 26)), with: .color(.mint))
                for index in [3,5,7,9] {
                    let p = point(pose[index])
                    canvas.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.mint.opacity(0.8)))
                }
                var ground = Path(); ground.move(to: CGPoint(x: 20, y: size.height * 0.9)); ground.addLine(to: CGPoint(x: size.width - 20, y: size.height * 0.9))
                canvas.stroke(ground, with: .color(.white.opacity(0.15)), lineWidth: 2)
                if ExerciseGuide.forName(name).movement == .wallPushup {
                    var wall = Path(); wall.move(to: CGPoint(x: size.width * 0.80, y: size.height * 0.18)); wall.addLine(to: CGPoint(x: size.width * 0.80, y: size.height * 0.90))
                    canvas.stroke(wall, with: .color(.white.opacity(0.25)), lineWidth: 3)
                }
            }
        }
        .accessibilityLabel("\(name)简化动作示意；动作要点见下方")
        }
    }

    // Head, shoulder, hip, two elbow/hand pairs, two knee/foot pairs.
    private func joints(_ movement: ExerciseMovement, _ t: Double) -> [(Double, Double)] {
        var p: [(Double, Double)] = [(0.50,0.16),(0.50,0.29),(0.50,0.57),(0.37,0.43),(0.34,0.57),(0.63,0.43),(0.66,0.57),(0.41,0.72),(0.38,0.88),(0.59,0.72),(0.62,0.88)]
        switch movement {
        case .squat:
            p[0].1 += t * 0.19; p[1].1 += t * 0.19; p[2].1 += t * 0.17
            p[7] = (0.33,0.73 + t * 0.06); p[9] = (0.67,0.73 + t * 0.06)
            p[3] = (0.36,0.39 + t * 0.12); p[4] = (0.44,0.38 + t * 0.12)
            p[5] = (0.64,0.39 + t * 0.12); p[6] = (0.56,0.38 + t * 0.12)
        case .hinge, .row:
            let bend = movement == .row ? 0.75 : t
            p[0] = (0.47 + bend * 0.16,0.20 + bend * 0.17); p[1] = (0.48 + bend * 0.13,0.32 + bend * 0.14)
            p[2] = (0.44,0.61); p[7] = (0.38,0.75); p[9] = (0.56,0.74)
            if movement == .row {
                p[3] = (0.43,0.55 - t * 0.13); p[4] = (0.54,0.65 - t * 0.17)
                p[5] = (0.62,0.55 - t * 0.10); p[6] = (0.68,0.65 - t * 0.16)
            }
        case .chestPress:
            p = [(0.22,0.66),(0.31,0.72),(0.60,0.73),(0.40,0.61 - t * 0.18),(0.35,0.47 - t * 0.16),(0.47,0.66 - t * 0.18),(0.43,0.52 - t * 0.16),(0.73,0.59),(0.83,0.87),(0.67,0.61),(0.75,0.87)]
        case .pushup:
            p = [(0.24,0.33 + t * 0.16),(0.33,0.42 + t * 0.16),(0.56,0.60 + t * 0.08),(0.25 - t * 0.05,0.65),(0.29,0.87),(0.41 + t * 0.05,0.66),(0.40,0.87),(0.72,0.72),(0.87,0.87),(0.67,0.73),(0.80,0.87)]
        case .wallPushup:
            p = [(0.47 + t * 0.10,0.16),(0.50 + t * 0.10,0.29),(0.40 + t * 0.08,0.59),(0.66,0.34 + t * 0.08),(0.80,0.31),(0.66,0.39 + t * 0.08),(0.80,0.36),(0.35,0.74),(0.29,0.88),(0.44,0.74),(0.39,0.88)]
        case .press:
            p[3] = (0.32,0.36 - t * 0.16); p[4] = (0.35 + t * 0.05,0.25 - t * 0.17)
            p[5] = (0.68,0.36 - t * 0.16); p[6] = (0.65 - t * 0.05,0.25 - t * 0.17)
        case .raise:
            p[3] = (0.39 - t * 0.15,0.43 - t * 0.10); p[4] = (0.35 - t * 0.20,0.56 - t * 0.21)
            p[5] = (0.61 + t * 0.15,0.43 - t * 0.10); p[6] = (0.65 + t * 0.20,0.56 - t * 0.21)
        case .curl:
            p[4] = (0.32 + t * 0.10,0.57 - t * 0.25); p[6] = (0.68 - t * 0.10,0.57 - t * 0.25)
        case .triceps:
            p[3] = (0.40,0.21); p[5] = (0.60,0.21)
            p[4] = (0.46,0.28 - t * 0.23); p[6] = (0.54,0.28 - t * 0.23)
        case .bridge:
            p = [(0.21,0.83),(0.31,0.82),(0.56,0.82 - t * 0.24),(0.31,0.86),(0.48,0.87),(0.39,0.85),(0.54,0.87),(0.70,0.60),(0.81,0.88),(0.63,0.64),(0.72,0.88)]
        case .plank, .sidePlank:
            p = [(0.21,0.43),(0.31,0.50),(0.56,0.65),(0.31,0.85),(0.43,0.87),(0.35,0.84),(0.45,0.87),(0.72,0.76),(0.88,0.87),(0.70,0.75),(0.86,0.86)]
            if movement == .sidePlank { p[5] = (0.39,0.35); p[6] = (0.39,0.18) }
        case .deadBug:
            p = [(0.22,0.79),(0.32,0.77),(0.56,0.79),(0.33 - t * 0.09,0.53),(0.34 - t * 0.18,0.31 + t * 0.27),(0.44,0.54),(0.43,0.30),(0.67 + t * 0.07,0.59 + t * 0.09),(0.71 + t * 0.13,0.42 + t * 0.34),(0.60,0.53),(0.59,0.31)]
        case .birdDog:
            p = [(0.22,0.43),(0.31,0.54),(0.56,0.59),(0.28 - t * 0.07,0.71 - t * 0.13),(0.29 - t * 0.17,0.87 - t * 0.28),(0.37,0.70),(0.36,0.87),(0.64,0.79),(0.74,0.87),(0.66 + t * 0.10,0.72 - t * 0.12),(0.79 + t * 0.08,0.81 - t * 0.21)]
        case .lunge:
            p[0].1 += t * 0.13; p[1].1 += t * 0.13; p[2].1 += t * 0.10
            p[7] = (0.32,0.71 + t * 0.09); p[8] = (0.25,0.88); p[9] = (0.66,0.76 + t * 0.08); p[10] = (0.80,0.88)
        case .calf:
            for i in 0...9 { p[i].1 -= t * 0.04 }
        case .walk, .checklist:
            let wave = (t - 0.5) * 0.15
            p[4].0 += wave; p[6].0 -= wave; p[8].0 -= wave; p[10].0 += wave
            p[7].1 -= max(0,wave); p[9].1 -= max(0,-wave)
        case .stretch:
            p[3] = (0.36,0.30); p[4] = (0.54,0.29); p[5] = (0.64,0.31); p[6] = (0.47,0.33)
            p[0].0 += (t - 0.5) * 0.03
        case .custom: break
        }
        return p
    }
}
