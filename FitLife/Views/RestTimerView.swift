import SwiftUI
import Combine
import AudioToolbox

struct RestTimerView: View {
    @State private var duration = 90
    @State private var deadline: Date?
    @State private var remaining = 90
    @State private var paused = false
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 12) {
            Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                .font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                .accessibilityLabel("剩余 \(remaining) 秒")
            Picker("休息时长", selection: $duration) {
                ForEach([30, 60, 90, 120, 180], id: \.self) { Text("\($0) 秒").tag($0) }
            }.onChange(of: duration) { value in deadline = nil; paused = false; remaining = value }
            HStack {
                Button(deadline != nil ? "暂停" : (paused ? "继续" : "开始")) {
                    if deadline != nil { update(); deadline = nil; paused = true }
                    else {
                        if remaining == 0 { remaining = duration }
                        deadline = Date().addingTimeInterval(TimeInterval(remaining)); paused = false
                    }
                }.buttonStyle(.borderedProminent)
                Button("重置") { deadline = nil; paused = false; remaining = duration }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .onReceive(ticker) { _ in update() }
    }
    private func update() {
        guard let end = deadline else { return }
        remaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
        if remaining == 0 {
            deadline = nil; paused = false
            AudioServicesPlaySystemSound(1005)
        }
    }
}
