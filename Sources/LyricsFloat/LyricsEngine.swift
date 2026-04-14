import Foundation
import Combine

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let start: Double
    let end: Double
}

@MainActor
final class LyricsOverlayController: ObservableObject {
    @Published var title: String = "Apple Music"
    @Published var artist: String = "未播放"
    @Published var lines: [LyricLine] = []
    @Published var currentLineID: LyricLine.ID?
    @Published var lineProgress: Double = 0
    @Published var scale: CGFloat = 1.0
    @Published var isPlaying: Bool = false

    private var timer: AnyCancellable?
    private var lastTrackKey: String = ""

    init() {
        timer = Timer.publish(every: 0.33, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    func zoom(by delta: CGFloat) {
        scale = min(max(scale * delta, 0.7), 2.0)
    }

    private func tick() {
        guard let snapshot = MusicBridge.fetchSnapshot() else {
            isPlaying = false
            return
        }

        title = snapshot.title
        artist = snapshot.artist
        isPlaying = snapshot.isPlaying

        let trackKey = "\(snapshot.title)|\(snapshot.artist)|\(snapshot.duration)"
        if trackKey != lastTrackKey {
            lastTrackKey = trackKey
            lines = buildTimeline(from: snapshot.lyrics, duration: snapshot.duration)
        }

        updateCurrentLine(position: snapshot.position)
    }

    private func buildTimeline(from rawLyrics: String, duration: Double) -> [LyricLine] {
        let normalized = rawLyrics
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let pureLines = normalized
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pureLines.isEmpty else {
            return [LyricLine(text: "当前歌曲没有可用歌词", start: 0, end: max(5, duration))]
        }

        let totalChars = pureLines.reduce(0) { $0 + max($1.count, 2) }
        let totalDuration = max(duration, Double(pureLines.count) * 2.4)

        var cursor = 0.0
        var timeline: [LyricLine] = []
        for text in pureLines {
            let weight = Double(max(text.count, 2)) / Double(totalChars)
            let segment = max(1.4, totalDuration * weight)
            let start = cursor
            let end = min(totalDuration, cursor + segment)
            timeline.append(LyricLine(text: text, start: start, end: end))
            cursor = end
        }

        if let last = timeline.last, last.end < totalDuration {
            let extended = LyricLine(text: last.text, start: last.start, end: totalDuration)
            timeline[timeline.count - 1] = extended
        }

        return timeline
    }

    private func updateCurrentLine(position: Double) {
        guard !lines.isEmpty else {
            currentLineID = nil
            lineProgress = 0
            return
        }

        let current = lines.first { position >= $0.start && position <= $0.end } ?? lines.last!
        currentLineID = current.id
        let denominator = max(current.end - current.start, 0.1)
        lineProgress = min(max((position - current.start) / denominator, 0), 1)
    }
}
