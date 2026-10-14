import SwiftUI

extension TrainingProgram {
    var displayTitle: String { isOriginal ? "28天居家减脂" : name }
    var coverName: String { goal == "增肌" || level == "中级" ? "CourseStrength" : "CourseHome" }
}

struct CourseCard: View {
    let title: String
    let subtitle: String
    let image: String
    let badge: String
    var progress: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(image).resizable().scaledToFill().frame(height: 180).clipped()
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text(badge).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.2), in: Capsule())
                    Text(title).font(.title2.bold()).lineLimit(2)
                }.foregroundStyle(.white).padding(18)
                HStack { Spacer(); Image(systemName: "play.fill").font(.title3).foregroundStyle(.white).padding(14).background(.white.opacity(0.18), in: Circle()) }
                    .padding(18).frame(maxHeight: .infinity, alignment: .top)
            }.frame(height: 180)
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                if let value = progress { ProgressView(value: value).tint(.green) }
                Label("离线课程 · 动画 / 语音跟练", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            }.padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.04), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct SpringCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
