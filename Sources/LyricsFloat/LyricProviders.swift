import Foundation

enum LRCParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#,
        options: []
    )

    static func parse(raw: String, duration: Double) -> [LyricLine]? {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        var entries: [(start: Double, text: String)] = []
        for row in normalized.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(row)
            let range = NSRange(location: 0, length: (line as NSString).length)
            let matches = regex.matches(in: line, options: [], range: range)
            guard !matches.isEmpty else { continue }

            let text = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }

            for match in matches {
                guard let minutesRange = Range(match.range(at: 1), in: line),
                      let secondsRange = Range(match.range(at: 2), in: line) else {
                    continue
                }

                let minutes = Double(line[minutesRange]) ?? 0
                let seconds = Double(line[secondsRange]) ?? 0

                var fraction = 0.0
                if let fractionRange = Range(match.range(at: 3), in: line) {
                    let fractionText = String(line[fractionRange])
                    let fractionValue = Double(fractionText) ?? 0
                    switch fractionText.count {
                    case 1: fraction = fractionValue / 10.0
                    case 2: fraction = fractionValue / 100.0
                    default: fraction = fractionValue / 1000.0
                    }
                }

                let start = minutes * 60 + seconds + fraction
                entries.append((start: start, text: text))
            }
        }

        guard !entries.isEmpty else { return nil }
        entries.sort { $0.start < $1.start }

        var result: [LyricLine] = []
        for index in entries.indices {
            let current = entries[index]
            let nextStart = (index + 1 < entries.count) ? entries[index + 1].start : max(duration, current.start + 4.0)
            let end = max(nextStart, current.start + 0.05)
            result.append(LyricLine(text: current.text, start: current.start, end: end))
        }

        return result
    }
}

enum LocalLRCProvider {
    static func loadLyrics(title: String, artist: String, album: String, persistentID: String) -> String? {
        let manager = FileManager.default
        let directories = candidateDirectories(using: manager)
        let preferredNames = candidateNames(title: title, artist: artist, persistentID: persistentID)

        for directory in directories {
            for filename in preferredNames {
                let url = directory.appendingPathComponent(filename)
                if manager.fileExists(atPath: url.path),
                   let text = try? String(contentsOf: url, encoding: .utf8),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }

        let titleKey = normalize(title)
        let artistKey = normalize(artist)
        let albumKey = normalize(album)

        var bestMatch: (score: Int, url: URL)?
        for directory in directories {
            guard let files = try? manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension.lowercased() == "lrc" {
                let key = normalize(file.deletingPathExtension().lastPathComponent)
                var score = 0
                if !titleKey.isEmpty && key.contains(titleKey) { score += 4 }
                if !artistKey.isEmpty && key.contains(artistKey) { score += 3 }
                if !albumKey.isEmpty && key.contains(albumKey) { score += 1 }

                if score > (bestMatch?.score ?? 0) {
                    bestMatch = (score, file)
                }
            }
        }

        if let bestURL = bestMatch?.url,
           let text = try? String(contentsOf: bestURL, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return nil
    }

    private static func candidateDirectories(using manager: FileManager) -> [URL] {
        var result: [URL] = []
        let cwd = URL(fileURLWithPath: manager.currentDirectoryPath, isDirectory: true)
        result.append(cwd.appendingPathComponent("Lyrics", isDirectory: true))

        if let home = manager.homeDirectoryForCurrentUser as URL? {
            result.append(home.appendingPathComponent("Music/LyricsFloat/Lyrics", isDirectory: true))
            result.append(home.appendingPathComponent("Library/Application Support/LyricsFloat/Lyrics", isDirectory: true))
        }

        return result
    }

    private static func candidateNames(title: String, artist: String, persistentID: String) -> [String] {
        var names: [String] = []
        if !persistentID.isEmpty {
            names.append("\(persistentID).lrc")
        }

        let safeTitle = sanitizeFilename(title)
        let safeArtist = sanitizeFilename(artist)

        names.append("\(safeTitle) - \(safeArtist).lrc")
        names.append("\(safeArtist) - \(safeTitle).lrc")
        names.append("\(safeTitle).lrc")
        return names
    }

    private static func sanitizeFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return raw.components(separatedBy: invalid).joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return lowered.components(separatedBy: separators).joined()
    }
}

enum NeteaseLyricProvider {
    static func fetchLyrics(title: String, artist: String) async -> String? {
        let query = "\(title) \(artist)"
        guard let songID = await searchSongID(query: query) else { return nil }
        return await fetchLRC(songID: songID)
    }

    private static func searchSongID(query: String) async -> Int? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.163.com/api/search/get/web?type=1&offset=0&limit=5&s=\(encoded)") else {
            return nil
        }
        guard let data = await request(url: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]],
              !songs.isEmpty else {
            return nil
        }

        let splits = query.split(separator: " ", maxSplits: 1).map(String.init)
        let titleKey = normalize(splits.first ?? query)
        let artistKey = normalize(splits.count > 1 ? splits[1] : "")

        var best: (score: Int, id: Int)?
        for song in songs {
            guard let id = song["id"] as? Int else { continue }
            let name = normalize(song["name"] as? String ?? "")

            let artists = (song["artists"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }
                .joined(separator: " ")
            let artistJoined = normalize(artists)

            var score = 0
            if !titleKey.isEmpty {
                if name == titleKey { score += 8 }
                else if name.contains(titleKey) { score += 5 }
            }
            if !artistKey.isEmpty {
                if artistJoined.contains(artistKey) { score += 4 }
            }

            if score > (best?.score ?? -1) {
                best = (score, id)
            }
        }

        return best?.id ?? (songs.first?["id"] as? Int)
    }

    private static func fetchLRC(songID: Int) async -> String? {
        guard let url = URL(
            string: "https://music.163.com/api/song/lyric?id=\(songID)&lv=-1&kv=-1&tv=-1"
        ) else {
            return nil
        }
        guard let data = await request(url: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lyric = lrc["lyric"] as? String,
              !lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return lyric
    }

    private static func request(url: URL) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 5.0
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return lowered.components(separatedBy: separators).joined()
    }
}
