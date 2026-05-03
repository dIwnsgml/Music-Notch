import Foundation
import AppKit

private enum LyricsCacheStore {
    static let entriesKey = "lyricsCacheV2"
    static let globalOffsetKey = "globalLyricOffset"
    static let legacyOffsetKey = "lyricOffset"
    static let migratedGlobalOffsetKey = "didMigrateGlobalLyricOffset"
    static let maxEntries = 250
}

private nonisolated enum LyricsSearchNetwork {
    static func search(title: String, artist: String, sources: Set<LyricsSearchSource>) async -> [LyricsSearchResult] {
        let results = await withTaskGroup(of: [LyricsSearchResult].self) { group in
            if sources.contains(.lrclib) {
                group.addTask { await searchLRCLIB(title: title, artist: artist) }
            }
            if sources.contains(.lyricsOVH) {
                group.addTask { await searchLyricsOVH(title: title, artist: artist) }
            }
            if sources.contains(.netease) {
                group.addTask { await searchNetease(title: title, artist: artist) }
            }

            var collected: [LyricsSearchResult] = []
            for await partial in group {
                collected.append(contentsOf: partial)
            }
            return collected
        }

        return results.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.source.rawValue < rhs.source.rawValue }
            return lhs.score > rhs.score
        }
    }

    static func parseLRC(_ lrcData: String) -> [LyricLine] {
        var parsed: [LyricLine] = []
        let lines = lrcData.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("["), let bracketEnd = line.firstIndex(of: "]") {
                let timeString = String(line[line.index(after: line.startIndex)..<bracketEnd])
                let text = String(line[line.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)
                let timeParts = timeString.components(separatedBy: ":")
                if timeParts.count == 2, let min = Double(timeParts[0]), let sec = Double(timeParts[1]), !text.isEmpty {
                    parsed.append(LyricLine(time: (min * 60) + sec, text: text))
                }
            }
        }

        return parsed
    }

    static func parseUnsynced(_ text: String) -> [LyricLine] {
        var parsed: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        var fakeTime = 0.0

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty {
                parsed.append(LyricLine(time: fakeTime, text: t))
                fakeTime += 3.5
            }
        }

        return parsed
    }

    private static func searchLRCLIB(title: String, artist: String) async -> [LyricsSearchResult] {
        var results: [LyricsSearchResult] = []

        if !artist.isEmpty,
           let exactResult = await fetchLRCLIBExact(title: title, artist: artist) {
            results.append(exactResult)
        }

        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(title) \(artist)".trimmingCharacters(in: .whitespaces))]

        guard let url = components?.url else { return results }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("WaveNotch v1.0", forHTTPHeaderField: "User-Agent")

        guard let data = await fetchData(request),
              let tracks = try? JSONDecoder().decode([LRCTrack].self, from: data) else {
            return results
        }

        for track in tracks.prefix(12) {
            let candidateTitle = track.trackName ?? title
            let candidateArtist = track.artistName ?? artist
            let score = matchScore(apiTitle: candidateTitle, apiArtist: candidateArtist, targetTitle: title, targetArtist: artist)

            if let result = makeResult(
                source: .lrclib,
                title: candidateTitle,
                artist: candidateArtist,
                album: track.albumName,
                syncedLyrics: track.syncedLyrics,
                plainLyrics: track.plainLyrics,
                score: score
            ) {
                results.append(result)
            }
        }

        return results
    }

    private static func fetchLRCLIBExact(title: String, artist: String) async -> LyricsSearchResult? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("WaveNotch v1.0", forHTTPHeaderField: "User-Agent")

        guard let data = await fetchData(request),
              let track = try? JSONDecoder().decode(LRCTrack.self, from: data) else {
            return nil
        }

        return makeResult(
            source: .lrclib,
            title: track.trackName ?? title,
            artist: track.artistName ?? artist,
            album: track.albumName,
            syncedLyrics: track.syncedLyrics,
            plainLyrics: track.plainLyrics,
            score: 1.0
        )
    }

    private static func searchLyricsOVH(title: String, artist: String) async -> [LyricsSearchResult] {
        guard !artist.isEmpty else { return [] }

        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artist
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "https://api.lyrics.ovh/v1/\(encodedArtist)/\(encodedTitle)") else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        guard let data = await fetchData(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lyricsText = json["lyrics"] as? String,
              !lyricsText.isEmpty else {
            return []
        }

        let cleanText = lyricsText.replacingOccurrences(of: "Paroles de la chanson", with: "")
        guard let result = makeResult(
            source: .lyricsOVH,
            title: title,
            artist: artist,
            album: nil,
            syncedLyrics: nil,
            plainLyrics: cleanText,
            score: 0.72
        ) else {
            return []
        }

        return [result]
    }

    private static func searchNetease(title: String, artist: String) async -> [LyricsSearchResult] {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "https://music.163.com/api/search/pc") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3.0
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "s", value: query),
            URLQueryItem(name: "type", value: "1")
        ]
        request.httpBody = bodyComponents.query?.data(using: .utf8)

        guard let data = await fetchData(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }

        return await withTaskGroup(of: LyricsSearchResult?.self) { group in
            for song in songs.prefix(3) {
                guard let id = song["id"] as? Int else { continue }
                let candidateTitle = song["name"] as? String ?? title
                let candidateArtist = neteaseArtistNames(from: song) ?? artist
                let album = (song["album"] as? [String: Any])?["name"] as? String
                group.addTask {
                    guard let lyricText = await fetchNeteaseLyric(id: id) else {
                        return nil
                    }

                    let score = matchScore(apiTitle: candidateTitle, apiArtist: candidateArtist, targetTitle: title, targetArtist: artist) * 0.92

                    return makeResult(
                        source: .netease,
                        title: candidateTitle,
                        artist: candidateArtist,
                        album: album,
                        syncedLyrics: lyricText,
                        plainLyrics: nil,
                        score: score
                    )
                }
            }

            var results: [LyricsSearchResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }
    }

    private static func fetchNeteaseLyric(id: Int) async -> String? {
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        guard let data = await fetchData(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lyricText = lrc["lyric"] as? String,
              !lyricText.isEmpty else {
            return nil
        }

        return lyricText
    }

    private static func fetchData(_ request: URLRequest) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private static func makeResult(
        source: LyricsSearchSource,
        title: String,
        artist: String,
        album: String?,
        syncedLyrics: String?,
        plainLyrics: String?,
        score: Double
    ) -> LyricsSearchResult? {
        if let syncedLyrics, !syncedLyrics.isEmpty {
            let parsed = parseLRC(syncedLyrics)
            if !parsed.isEmpty {
                return LyricsSearchResult(
                    source: source,
                    title: title,
                    artist: artist,
                    album: album,
                    lyricsText: syncedLyrics,
                    lines: parsed,
                    isSynced: true,
                    score: score
                )
            }
        }

        if let plainLyrics, !plainLyrics.isEmpty {
            let parsed = parseUnsynced(plainLyrics)
            if !parsed.isEmpty {
                return LyricsSearchResult(
                    source: source,
                    title: title,
                    artist: artist,
                    album: album,
                    lyricsText: plainLyrics,
                    lines: parsed,
                    isSynced: false,
                    score: score * 0.78
                )
            }
        }

        return nil
    }

    private static func neteaseArtistNames(from song: [String: Any]) -> String? {
        guard let artists = song["artists"] as? [[String: Any]] else { return nil }
        let names = artists.compactMap { $0["name"] as? String }
        guard !names.isEmpty else { return nil }
        return names.joined(separator: ", ")
    }

    private static func matchScore(apiTitle: String, apiArtist: String, targetTitle: String, targetArtist: String) -> Double {
        let normalizedAPITitle = normalize(apiTitle)
        let normalizedTargetTitle = normalize(targetTitle)
        let normalizedAPIArtist = normalize(apiArtist)
        let normalizedTargetArtist = normalize(targetArtist)

        var score = 0.35
        if normalizedAPITitle == normalizedTargetTitle {
            score += 0.42
        } else if normalizedAPITitle.contains(normalizedTargetTitle) || normalizedTargetTitle.contains(normalizedAPITitle) {
            score += 0.25
        }

        if normalizedTargetArtist.isEmpty {
            score += 0.12
        } else if normalizedAPIArtist == normalizedTargetArtist {
            score += 0.30
        } else if normalizedAPIArtist.contains(normalizedTargetArtist) || normalizedTargetArtist.contains(normalizedAPIArtist) {
            score += 0.18
        }

        return min(score, 1.0)
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
    }
}

extension NowPlayingManager {
    static func loadLyricsCache() -> [String: CachedLyricsEntry] {
        guard let data = UserDefaults.standard.data(forKey: LyricsCacheStore.entriesKey),
              let decoded = try? JSONDecoder().decode([String: CachedLyricsEntry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func saveLyricsCache(_ cache: [String: CachedLyricsEntry]) {
        let trimmed = Dictionary(
            uniqueKeysWithValues: cache
                .sorted { $0.value.updatedAt > $1.value.updatedAt }
                .prefix(LyricsCacheStore.maxEntries)
                .map { ($0.key, $0.value) }
        )

        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: LyricsCacheStore.entriesKey)
    }

    func migrateGlobalLyricOffsetIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: LyricsCacheStore.migratedGlobalOffsetKey) else { return }

        if defaults.object(forKey: LyricsCacheStore.globalOffsetKey) == nil,
           defaults.object(forKey: LyricsCacheStore.legacyOffsetKey) != nil {
            defaults.set(defaults.double(forKey: LyricsCacheStore.legacyOffsetKey), forKey: LyricsCacheStore.globalOffsetKey)
        }

        defaults.set(true, forKey: LyricsCacheStore.migratedGlobalOffsetKey)
    }

    private func persistLyricsCache() {
        Self.saveLyricsCache(lyricsCache)
    }

    private func cleanedLyricTitle(_ title: String) -> String {
        var cleanTitle = title
            .replacingOccurrences(of: "(Official Video)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[Official Music Video]", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "(Lyrics)", with: "", options: .caseInsensitive)

        if let regex = try? NSRegularExpression(pattern: "(\\(|-)?\\s*(feat\\.|ft\\.|featuring).*?(\\)|$)", options: .caseInsensitive) {
            cleanTitle = regex.stringByReplacingMatches(
                in: cleanTitle,
                range: NSRange(cleanTitle.startIndex..., in: cleanTitle),
                withTemplate: ""
            )
        }

        return cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func lyricsCacheKey(title: String, artist: String) -> String {
        let cleanTitle = cleanedLyricTitle(title).lowercased()
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(cleanTitle)-\(cleanArtist)"
    }

    private func currentSongParts() -> (title: String, artist: String) {
        let parts = currentSong.components(separatedBy: " - ")
        let title = (parts.first ?? currentSong).trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = parts.count > 1 ? parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return (title, artist)
    }

    func currentLyricsSearchQuery() -> LyricsSearchQuery {
        let song = currentSongParts()
        return LyricsSearchQuery(title: song.title, artist: song.artist)
    }

    // Master entry point. Handles per-song cache, manual refreshes, and no-lyrics suppression.
    func fetchLyricsEngine(title: String, artist: String, forceRefresh: Bool = false, cacheKeyOverride: String? = nil) {
        let searchTicket = UUID()
        currentLyricSearchID = searchTicket

        let cleanTitle = cleanedLyricTitle(title)
        guard !cleanTitle.isEmpty else { return }

        let cacheKey = cacheKeyOverride ?? lyricsCacheKey(title: cleanTitle, artist: artist)
        currentLyricsCacheKey = cacheKey

        if let cachedEntry = lyricsCache[cacheKey], !forceRefresh, (cachedEntry.noLyrics || !cachedEntry.lyrics.isEmpty) {
            DispatchQueue.main.async {
                self.currentSongLyricOffset = cachedEntry.songOffset
                self.lyricsDisabledForCurrentSong = cachedEntry.noLyrics
                self.lyrics = cachedEntry.noLyrics ? [] : cachedEntry.lyrics
                self.activeLyricIndex = 0
                self.isSearchingLyrics = false
                self.updateActiveLyric()
            }
            return
        }

        var startingSongOffset = lyricsCache[cacheKey]?.songOffset ?? 0.0
        if forceRefresh, var existing = lyricsCache[cacheKey] {
            existing.noLyrics = false
            existing.updatedAt = Date()
            lyricsCache[cacheKey] = existing
            startingSongOffset = existing.songOffset
            persistLyricsCache()
        }

        DispatchQueue.main.async {
            self.currentSongLyricOffset = startingSongOffset
            self.lyricsDisabledForCurrentSong = false
            self.isSearchingLyrics = true
            self.lyrics = []
            self.activeLyricIndex = 0
        }

        lyricSearchTask?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.currentLyricSearchID == searchTicket else { return }
            self.fetchLRCLibGet(title: cleanTitle, artist: artist, cacheKey: cacheKey, ticket: searchTicket)
        }

        lyricSearchTask = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (forceRefresh ? 0.1 : 2.0), execute: workItem)
    }

    // MARK: - Sources

    private func fetchLRCLibGet(title: String, artist: String, cacheKey: String, ticket: UUID) {
        guard !artist.isEmpty else {
            fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            return
        }

        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components?.url else {
            fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        req.setValue("WaveNotch v1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, _, err in
            guard self.currentLyricSearchID == ticket else { return }

            if err != nil {
                self.fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
                return
            }

            if let data,
               let track = try? JSONDecoder().decode(LRCTrack.self, from: data),
               let synced = track.syncedLyrics,
               !synced.isEmpty {
                self.saveAndPublish(lyricsText: synced, isSynced: true, cacheKey: cacheKey, ticket: ticket)
            } else {
                self.fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            }
        }.resume()
    }

    private func fetchLRCLibSearch(title: String, artist: String, cacheKey: String, ticket: UUID) {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components?.url else {
            fetchOVH(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        req.setValue("WaveNotch v1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard self.currentLyricSearchID == ticket else { return }

            if let data, let tracks = try? JSONDecoder().decode([LRCTrack].self, from: data) {
                for track in tracks {
                    if let synced = track.syncedLyrics,
                       !synced.isEmpty,
                       self.isStrictMatch(
                        apiTitle: track.trackName ?? "",
                        apiArtist: track.artistName ?? "",
                        targetTitle: title,
                        targetArtist: artist
                       ) {
                        self.saveAndPublish(lyricsText: synced, isSynced: true, cacheKey: cacheKey, ticket: ticket)
                        return
                    }
                }
            }

            self.fetchOVH(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
        }.resume()
    }

    private func fetchOVH(title: String, artist: String, cacheKey: String, ticket: UUID) {
        guard !artist.isEmpty else {
            fetchNetease(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            return
        }

        let eArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artist
        let eTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        let urlStr = "https://api.lyrics.ovh/v1/\(eArtist)/\(eTitle)"

        guard let url = URL(string: urlStr) else {
            fetchNetease(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard self.currentLyricSearchID == ticket else { return }

            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lyricsText = json["lyrics"] as? String,
               !lyricsText.isEmpty {
                let cleanText = lyricsText.replacingOccurrences(of: "Paroles de la chanson", with: "")
                self.saveAndPublish(lyricsText: cleanText, isSynced: false, cacheKey: cacheKey, ticket: ticket)
            } else {
                self.fetchNetease(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            }
        }.resume()
    }

    private func fetchNetease(title: String, artist: String, cacheKey: String, ticket: UUID) {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        var req = URLRequest(url: URL(string: "https://music.163.com/api/search/pc")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 4.0
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "s", value: query),
            URLQueryItem(name: "type", value: "1")
        ]
        req.httpBody = bodyComponents.query?.data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard self.currentLyricSearchID == ticket else { return }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  let firstSong = songs.first,
                  let id = firstSong["id"] as? Int else {
                self.handleLyricsNotFound(ticket: ticket)
                return
            }

            let lyricUrl = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1")!
            var lReq = URLRequest(url: lyricUrl)
            lReq.timeoutInterval = 4.0
            lReq.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
            lReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: lReq) { lData, _, _ in
                guard self.currentLyricSearchID == ticket else { return }

                if let lData,
                   let lJson = try? JSONSerialization.jsonObject(with: lData) as? [String: Any],
                   let lrc = lJson["lrc"] as? [String: Any],
                   let lyricText = lrc["lyric"] as? String,
                   !lyricText.isEmpty {
                    self.saveAndPublish(lyricsText: lyricText, isSynced: true, cacheKey: cacheKey, ticket: ticket)
                } else {
                    self.handleLyricsNotFound(ticket: ticket)
                }
            }.resume()
        }.resume()
    }

    // MARK: - Cache and state

    private func saveAndPublish(lyricsText: String, isSynced: Bool, cacheKey: String, ticket: UUID) {
        guard currentLyricSearchID == ticket else { return }

        let parsedArray = isSynced ? parseLRC(lyricsText) : parseUnsynced(lyricsText)
        guard !parsedArray.isEmpty else {
            handleLyricsNotFound(ticket: ticket)
            return
        }

        DispatchQueue.main.async {
            let existingOffset = self.lyricsCache[cacheKey]?.songOffset ?? self.currentSongLyricOffset
            let entry = CachedLyricsEntry(
                lyrics: parsedArray,
                songOffset: existingOffset,
                noLyrics: false,
                updatedAt: Date()
            )
            self.lyricsCache[cacheKey] = entry
            self.persistLyricsCache()
            self.currentLyricsCacheKey = cacheKey
            self.currentSongLyricOffset = existingOffset
            self.lyricsDisabledForCurrentSong = false
            self.lyrics = parsedArray
            self.activeLyricIndex = 0
            self.isSearchingLyrics = false
            self.updateActiveLyric()
        }
    }

    private func handleLyricsNotFound(ticket: UUID) {
        guard currentLyricSearchID == ticket else { return }
        DispatchQueue.main.async {
            self.isSearchingLyrics = false
        }
    }

    func adjustCurrentSongLyricOffset(by delta: Double) {
        setCurrentSongLyricOffset(currentSongLyricOffset + delta)
    }

    func setCurrentSongLyricOffset(_ value: Double) {
        let clamped = min(max(value, -8.0), 8.0)
        currentSongLyricOffset = clamped

        let fallback = currentSongParts()
        let cacheKey = currentLyricsCacheKey ?? lyricsCacheKey(title: fallback.title, artist: fallback.artist)
        currentLyricsCacheKey = cacheKey

        var entry = lyricsCache[cacheKey] ?? CachedLyricsEntry(
            lyrics: lyrics,
            songOffset: clamped,
            noLyrics: lyricsDisabledForCurrentSong,
            updatedAt: Date()
        )
        entry.songOffset = clamped
        entry.updatedAt = Date()
        if !lyrics.isEmpty {
            entry.lyrics = lyrics
            entry.noLyrics = false
        } else {
            entry.noLyrics = lyricsDisabledForCurrentSong
        }
        lyricsCache[cacheKey] = entry
        persistLyricsCache()
        updateActiveLyric()
    }

    func markNoLyricsForCurrentSong() {
        lyricSearchTask?.cancel()
        currentLyricSearchID = UUID()

        let fallback = currentSongParts()
        let cacheKey = currentLyricsCacheKey ?? lyricsCacheKey(title: fallback.title, artist: fallback.artist)
        currentLyricsCacheKey = cacheKey

        let entry = CachedLyricsEntry(
            lyrics: [],
            songOffset: currentSongLyricOffset,
            noLyrics: true,
            updatedAt: Date()
        )

        lyricsCache[cacheKey] = entry
        persistLyricsCache()
        lyrics = []
        activeLyricIndex = 0
        isSearchingLyrics = false
        lyricsDisabledForCurrentSong = true
    }

    func retryLyricsForCurrentSong() {
        let fallback = currentSongParts()
        let cacheKey = currentLyricsCacheKey ?? lyricsCacheKey(title: fallback.title, artist: fallback.artist)
        currentLyricsCacheKey = cacheKey

        if var existing = lyricsCache[cacheKey] {
            existing.noLyrics = false
            existing.updatedAt = Date()
            lyricsCache[cacheKey] = existing
            persistLyricsCache()
        }

        fetchLyricsEngine(title: fallback.title, artist: fallback.artist, forceRefresh: true, cacheKeyOverride: cacheKey)
    }

    func toggleNoLyricsForCurrentSong() {
        if lyricsDisabledForCurrentSong {
            retryLyricsForCurrentSong()
        } else {
            markNoLyricsForCurrentSong()
        }
    }

    func promptForLyricsSearch() {
        LyricsSearchWindowManager.shared.show(nowPlaying: self)
    }

    func searchLyricsResults(title: String, artist: String, sources: Set<LyricsSearchSource>) async -> [LyricsSearchResult] {
        let cleanTitle = cleanedLyricTitle(title)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return [] }

        var results: [LyricsSearchResult] = []
        if sources.contains(.cache) {
            let fallback = currentSongParts()
            let cacheKey = currentLyricsCacheKey ?? lyricsCacheKey(title: fallback.title, artist: fallback.artist)
            if let cached = lyricsCache[cacheKey], !cached.noLyrics, !cached.lyrics.isEmpty {
                results.append(
                    LyricsSearchResult(
                        source: .cache,
                        title: fallback.title,
                        artist: fallback.artist,
                        album: nil,
                        lyricsText: cached.lyrics.map(\.text).joined(separator: "\n"),
                        lines: cached.lyrics,
                        isSynced: true,
                        score: 1.05
                    )
                )
            }
        }

        let remoteSources = sources.subtracting([.cache])
        if !remoteSources.isEmpty {
            let remoteResults = await LyricsSearchNetwork.search(title: cleanTitle, artist: cleanArtist, sources: remoteSources)
            results.append(contentsOf: remoteResults)
        }

        return uniqueLyricsResults(results)
    }

    func applyLyricsSearchResult(_ result: LyricsSearchResult) {
        let fallback = currentSongParts()
        let cacheKey = currentLyricsCacheKey ?? lyricsCacheKey(title: fallback.title, artist: fallback.artist)
        let existingOffset = lyricsCache[cacheKey]?.songOffset ?? currentSongLyricOffset

        lyricsCache[cacheKey] = CachedLyricsEntry(
            lyrics: result.lines,
            songOffset: existingOffset,
            noLyrics: false,
            updatedAt: Date()
        )
        persistLyricsCache()

        currentLyricsCacheKey = cacheKey
        currentSongLyricOffset = existingOffset
        lyricsDisabledForCurrentSong = false
        lyrics = result.lines
        activeLyricIndex = 0
        isSearchingLyrics = false
        updateActiveLyric()
    }

    private func uniqueLyricsResults(_ results: [LyricsSearchResult]) -> [LyricsSearchResult] {
        var seen = Set<String>()
        var unique: [LyricsSearchResult] = []

        for result in results.sorted(by: { $0.score > $1.score }) {
            let preview = result.lines.prefix(8).map(\.text).joined(separator: "|").lowercased()
            let key = [
                result.source.rawValue,
                result.title.lowercased(),
                result.artist.lowercased(),
                preview
            ].joined(separator: "::")

            if seen.insert(key).inserted {
                unique.append(result)
            }
        }

        return unique
    }

    // MARK: - Parsers

    private func parseLRC(_ lrcData: String) -> [LyricLine] {
        LyricsSearchNetwork.parseLRC(lrcData)
    }

    private func parseUnsynced(_ text: String) -> [LyricLine] {
        LyricsSearchNetwork.parseUnsynced(text)
    }

    func isStrictMatch(apiTitle: String, apiArtist: String, targetTitle: String, targetArtist: String) -> Bool {
        let t1 = apiTitle.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let t2 = targetTitle.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let a1 = apiArtist.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let a2 = targetArtist.lowercased().components(separatedBy: .alphanumerics.inverted).joined()

        let titleMatch = t1.contains(t2) || t2.contains(t1) || t1 == t2
        let artistMatch = a1.contains(a2) || a2.contains(a1) || a1 == a2 || a2.isEmpty || a1.isEmpty

        if targetTitle.lowercased().contains("cover") { return titleMatch }
        return titleMatch && artistMatch
    }

    func updateActiveLyric() {
        guard !lyrics.isEmpty else { return }

        let globalOffset = UserDefaults.standard.double(forKey: LyricsCacheStore.globalOffsetKey)
        let adjustedTime = currentTime + 0.05 + globalOffset + currentSongLyricOffset

        if let idx = lyrics.lastIndex(where: { $0.time <= adjustedTime }) {
            if activeLyricIndex != idx {
                activeLyricIndex = idx
            }
        } else if activeLyricIndex != 0 {
            activeLyricIndex = 0
        }
    }
}
