import AVFoundation
import Combine

final class CoachSpeech: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    var enabled = true
    func say(_ text: String) {
        guard enabled else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
