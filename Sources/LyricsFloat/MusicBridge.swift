import Foundation

struct MusicTrackSnapshot {
    let title: String
    let artist: String
    let album: String
    let persistentID: String
    let duration: Double
    let position: Double
    let lyrics: String
    let isPlaying: Bool
}

enum MusicBridge {
    static func fetchSnapshot() async -> MusicTrackSnapshot? {
        await Task.detached(priority: .userInitiated) {
            fetchSnapshotSync()
        }.value
    }

    private static func fetchSnapshotSync() -> MusicTrackSnapshot? {
        let script = """
        tell application "Music"
            if it is not running then return "NOT_RUNNING"
            if player state is stopped then return "STOPPED"
            set t to current track
            set _name to (get name of t)
            set _artist to (get artist of t)
            set _album to (get album of t)
            set _pid to ""
            try
                set _pid to (get persistent ID of t)
            end try
            set _duration to (get duration of t)
            set _position to (get player position)
            set _lyrics to (get lyrics of t)
            set _state to (player state as string)
            return _name & "|||" & _artist & "|||" & _album & "|||" & _pid & "|||" & (_duration as string) & "|||" & (_position as string) & "|||" & _state & "|||" & _lyrics
        end tell
        """

        guard let output = runAppleScript(script) else { return nil }
        if output == "NOT_RUNNING" || output == "STOPPED" {
            return nil
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 8 else { return nil }
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let persistentID = parts[3]
        let duration = Double(parts[4]) ?? 0
        let position = Double(parts[5]) ?? 0
        let state = parts[6].lowercased()
        let lyrics = parts[7...].joined(separator: "|||")

        return MusicTrackSnapshot(
            title: title,
            artist: artist,
            album: album,
            persistentID: persistentID,
            duration: duration,
            position: position,
            lyrics: lyrics,
            isPlaying: state.contains("playing")
        )
    }

    private static func runAppleScript(_ source: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty else {
                return nil
            }
            return text
        } catch {
            return nil
        }
    }
}
