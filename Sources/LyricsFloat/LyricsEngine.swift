import Foundation
import Combine

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let start: Double
    let end: Double
}

enum OverlayTheme: String, CaseIterable {
    case graphite
    case frosted

    var displayName: String {
        switch self {
        case .graphite: return "Graphite"
        case .frosted: return "Frosted"
        }
    }
}

private struct CachedLyrics {
    let lines: [LyricLine]
    let source: String
    let timed: Bool
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

    @Published var lyricsSource: String = "Apple Music"
    @Published var isLocked: Bool = false
    @Published var isClickThrough: Bool = false
    @Published var opacity: Double = 0.92
    @Published var theme: OverlayTheme = .graphite
    @Published var useNeteaseProvider: Bool = false

    private var timer: AnyCancellable?
    private var lyricsTask: Task<Void, Never>?
    private var lastTrackKey: String = ""
    private var cache: [String: CachedLyrics] = [:]

    init() {
        timer = Timer.publish(every: 0.33, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    deinit {
        timer?.cancel()
        lyricsTask?.cancel()
    }

    func zoom(by delta: CGFloat) {
        scale = min(max(scale * delta, 0.7), 2.0)
    }

    func toggleLock() {
        isLocked.toggle()
    }

    func toggleClickThrough() {
        isClickThrough.toggle()
    }

    func cycleOpacity() {
        let values: [Double] = [1.0, 0.92, 0.84, 0.76, 0.68]
        let nextIndex = (values.firstIndex(where: { abs($0 - opacity) < 0.01 }) ?? 0) + 1
        opacity = values[nextIndex % values.count]
    }

    func toggleTheme() {
        theme = (theme == .graphite) ? .frosted : .graphite
    }

    func toggleNeteaseProvider() {
        useNeteaseProvider.toggle()
        lastTrackKey = ""
    }

    private func tick() {
        guard let snapshot = MusicBridge.fetchSnapshot() else {
            isPlaying = false
            title = "Apple Music"
            artist = "未播放"
            lyricsSource = "等待播放"
            currentLineID = nil
            lineProgress = 0
            return
        }

        title = snapshot.title
        artist = snapshot.artist
        isPlaying = snapshot.isPlaying

        let trackKey = buildTrackKey(snapshot)
        if trackKey != lastTrackKey {
            lastTrackKey = trackKey
            handleTrackChange(snapshot: snapshot, trackKey: trackKey)
        }

        updateCurrentLine(position: snapshot.position)
    }

    private func handleTrackChange(snapshot: MusicTrackSnapshot, trackKey: String) {
        lyricsTask?.cancel()

        if let cached = cache[trackKey] {
            lines = cached.lines
            lyricsSource = cached.source
            if cached.timed {
                return
            }
        } else {
            applyFallbackLyrics(snapshot: snapshot, trackKey: trackKey)
        }

        let shouldUseNetease = useNeteaseProvider
        lyricsTask = Task { [weak self] in
            guard let self else { return }

            if let localRaw = LocalLRCProvider.loadLyrics(
                title: snapshot.title,
                artist: snapshot.artist,
                album: snapshot.album,
                persistentID: snapshot.persistentID
            ),
               let localTimed = LRCParser.parse(raw: localRaw, duration: snapshot.duration),
               !localTimed.isEmpty {
                self.applyExternalLyrics(localTimed, source: "本地 LRC", trackKey: trackKey)
                return
            }

            guard shouldUseNetease else { return }
            guard let remoteRaw = await NeteaseLyricProvider.fetchLyrics(title: snapshot.title, artist: snapshot.artist),
                  let remoteTimed = LRCParser.parse(raw: remoteRaw, duration: snapshot.duration),
                  !remoteTimed.isEmpty else {
                return
            }
            self.applyExternalLyrics(remoteTimed, source: "网易云 API", trackKey: trackKey)
        }
    }

    private func applyFallbackLyrics(snapshot: MusicTrackSnapshot, trackKey: String) {
        if let timedFromApple = LRCParser.parse(raw: snapshot.lyrics, duration: snapshot.duration),
           !timedFromApple.isEmpty {
            lines = timedFromApple
            lyricsSource = "Apple Music 时间轴"
            cache[trackKey] = CachedLyrics(lines: timedFromApple, source: lyricsSource, timed: true)
        } else {
            let estimated = buildEstimatedTimeline(from: snapshot.lyrics, duration: snapshot.duration)
            lines = estimated
            lyricsSource = "Apple Music 估算"
            cache[trackKey] = CachedLyrics(lines: estimated, source: lyricsSource, timed: false)
        }
    }

    private func applyExternalLyrics(_ externalLines: [LyricLine], source: String, trackKey: String) {
        guard trackKey == lastTrackKey else { return }
        lines = externalLines
        lyricsSource = source
        cache[trackKey] = CachedLyrics(lines: externalLines, source: source, timed: true)
    }

    private func buildTrackKey(_ snapshot: MusicTrackSnapshot) -> String {
        if !snapshot.persistentID.isEmpty {
            return "pid:\(snapshot.persistentID)"
        }
        return "\(snapshot.title)|\(snapshot.artist)|\(snapshot.album)|\(snapshot.duration)"
    }

    private func buildEstimatedTimeline(from rawLyrics: String, duration: Double) -> [LyricLine] {
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
            let segment = max(1.2, totalDuration * weight)
            let start = cursor
            let end = min(totalDuration, cursor + segment)
            timeline.append(LyricLine(text: text, start: start, end: end))
            cursor = end
        }

        if let last = timeline.last, last.end < totalDuration {
            timeline[timeline.count - 1] = LyricLine(text: last.text, start: last.start, end: totalDuration)
        }

        return timeline
    }

    private func updateCurrentLine(position: Double) {
        guard !lines.isEmpty else {
            currentLineID = nil
            lineProgress = 0
            return
        }

        let current: LyricLine
        if position < lines[0].start {
            current = lines[0]
        } else if let found = lines.first(where: { position >= $0.start && position <= $0.end }) {
            current = found
        } else {
            current = lines[lines.count - 1]
        }

        currentLineID = current.id
        let denominator = max(current.end - current.start, 0.05)
        lineProgress = min(max((position - current.start) / denominator, 0), 1)
    }
}
