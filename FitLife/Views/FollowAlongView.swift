import SwiftUI
import Combine

struct CoachLaunch: Identifiable {
    var id = UUID()
    let plan: WorkoutPlan
    let exercises: [Exercise]
}

struct FollowAlongView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let plan: WorkoutPlan
    @StateObject private var session: FollowAlongSession
    @StateObject private var speech = CoachSpeech()
    @State private var voices = true
    @State private var exitPrompt = false
    @State private var saved = false
    @State private var previousIdleTimer = false
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    init(plan: WorkoutPlan, exercises: [Exercise]) {
        self.plan = plan
        _session = StateObject(wrappedValue: FollowAlongSession(exercises: exercises, restSeconds: plan.restSeconds ?? 90))
    }
    private var displayName: String {
        guard let step = session.current else { return "完成" }
        if step.phase == .warmup { return "原地踏步" }
        if step.phase == .rest || step.phase == .cooldown { return "轻柔拉伸" }
        return step.title
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let step = session.current {
                        HStack { Text(phaseTitle(step.phase)).font(.headline).foregroundStyle(.mint); Spacer(); Text("\(session.index + 1) / \(session.steps.count)").foregroundStyle(.white.opacity(0.6)) }
                        ProgressView(value: session.progress).tint(.mint)
                        Text(step.title).font(.title.bold()).multilineTextAlignment(.center)
                        Text(step.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                        ExerciseAnimationView(name: displayName, paused: session.paused || step.phase == .prepare).frame(height: 220)
                        Text("动作示意 · 非真人视频 / 非动作识别").font(.caption).foregroundStyle(.white.opacity(0.55))
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(session.remaining / 60):\(String(format: "%02d", session.remaining % 60))")
                                .font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                            Text("剩余").foregroundStyle(.white.opacity(0.6))
                        }
                        if step.phase == .exercise {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(ExerciseGuide.forName(step.title).cues, id: \.self) { Text("• " + $0).font(.subheadline) }
                                Text("次数型动作按约 4 秒 / 次估时；不用赶节奏，做完目标可提前确认本组。").font(.caption).foregroundStyle(.white.opacity(0.6))
                            }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        }
                    } else {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(.mint).padding(.top, 40)
                        Text("跟练结束").font(.largeTitle.bold())
                        Text("已完成 \(session.completedSets) 组。跳过的组不会计入记录。").foregroundStyle(.white.opacity(0.7))
                        Button(saved ? "已保存训练记录" : "保存并返回") { saveAndExit() }.buttonStyle(.borderedProminent).tint(.mint)
                            .disabled(session.completedSets == 0 || saved)
                        Button("返回，不保存本次跟练") { dismiss() }.foregroundStyle(.white.opacity(0.7))
                    }
                }.padding(20)
            }
            .background(LinearGradient(colors: [Color(red: 0.06, green: 0.14, blue: 0.15), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle(plan.name).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("结束") { session.pause(); speech.stop(); exitPrompt = true } }
                ToolbarItem(placement: .confirmationAction) { Button { voices.toggle(); speech.enabled = voices; if !voices { speech.stop() } } label: { Image(systemName: voices ? "speaker.wave.2.fill" : "speaker.slash.fill") }.accessibilityLabel("中文语音提示") }
            }
            .safeAreaInset(edge: .bottom) {
                if !session.finished {
                    VStack(spacing: 10) {
                        HStack(spacing: 24) {
                            Button { session.previous() } label: { Image(systemName: "backward.end.fill").font(.title2) }.accessibilityLabel("上一步")
                            Button {
                                if session.paused { session.resume(); announce() } else { session.pause(); speech.stop() }
                            } label: { Image(systemName: session.paused ? "play.fill" : "pause.fill").font(.title).frame(width: 76, height: 60).background(.mint, in: Capsule()).foregroundStyle(.black) }
                            .accessibilityLabel(session.paused ? "开始或继续" : "暂停")
                            Button { session.skip() } label: { Image(systemName: "forward.end.fill").font(.title2) }.accessibilityLabel("跳过，不计完成")
                        }
                        if session.current?.phase == .exercise { Button("我已完成本组") { session.finishCurrent() }.font(.subheadline).tint(.mint) }
                    }.padding().frame(maxWidth: .infinity).background(.ultraThinMaterial)
                }
            }
            .onAppear {
                previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--preview-coach") { session.skip(); session.skip() }
                #endif
            }
            .onReceive(ticker) { _ in session.tick() }
            .onChange(of: session.index) { _ in if !session.paused { announce() } else if session.finished { speech.say("本次跟练结束") } }
            .onChange(of: session.remaining) { value in if !session.paused && (1...3).contains(value) { speech.say("\(value)") } }
            .onChange(of: session.paused) { value in UIApplication.shared.isIdleTimerDisabled = !value }
            .onChange(of: scenePhase) { value in if value != .active { session.pause(); speech.stop() } }
            .onDisappear { session.pause(); speech.stop(); UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
            .confirmationDialog("结束跟练？", isPresented: $exitPrompt, titleVisibility: .visible) {
                if session.completedSets > 0 { Button("保存已完成组并退出") { saveAndExit() } }
                Button("退出，不保存本次跟练", role: .destructive) { dismiss() }
                Button("继续跟练", role: .cancel) { session.resume(); announce() }
            }
        }.preferredColorScheme(.dark)
    }
    private func phaseTitle(_ phase: CoachPhase) -> String {
        switch phase { case .warmup: return "热身"; case .prepare: return "准备"; case .exercise: return "跟练"; case .rest: return "休息"; case .cooldown: return "放松" }
    }
    private func announce() { if let step = session.current { speech.say(phaseTitle(step.phase) + "，" + step.title + "，" + step.subtitle) } }
    private func saveAndExit() {
        guard !saved else { return }
        if session.completedSets > 0 { store.completeWorkout(plan, exercises: session.exercises) }
        saved = true; dismiss()
    }
}
