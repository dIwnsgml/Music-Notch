import Foundation

extension NowPlayingManager {
    
    func fetchLyricsEngine(title: String, artist: String) {
        DispatchQueue.main.async {
            self.isSearchingLyrics = true
            self.lyrics = []
            self.activeLyricIndex = 0
        }
        var cleanTitle = title.replacingOccurrences(of: "(Official Video)", with: "", options: .caseInsensitive).replacingOccurrences(of: "[Official Music Video]", with: "", options: .caseInsensitive).replacingOccurrences(of: "(Lyrics)", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
        
        if !artist.isEmpty {
            if let eTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let eArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "https://lrclib.net/api/get?track_name=\(eTitle)&artist_name=\(eArtist)") {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let track = try? JSONDecoder().decode(LRCTrack.self, from: data), let synced = track.syncedLyrics {
                        self.parseLRC(synced); DispatchQueue.main.async { self.isSearchingLyrics = false }; return
                    } else { self.executeSearchFallback(title: cleanTitle, artist: artist) }
                }.resume(); return
            }
        }
        self.executeSearchFallback(title: cleanTitle, artist: artist)
    }
    
    func executeSearchFallback(title: String, artist: String) {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        guard let eQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "https://lrclib.net/api/search?q=\(eQuery)") else {
            DispatchQueue.main.async { self.isSearchingLyrics = false }; return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { self.isSearchingLyrics = false } }
            guard let data = data, let tracks = try? JSONDecoder().decode([LRCTrack].self, from: data) else { return }
            for track in tracks {
                guard let synced = track.syncedLyrics else { continue }
                if self.isStrictMatch(apiTitle: track.trackName ?? "", apiArtist: track.artistName ?? "", targetTitle: title, targetArtist: artist) {
                    self.parseLRC(synced); return
                }
            }
        }.resume()
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
    
    func parseLRC(_ lrcData: String) {
        var parsed: [LyricLine] = []
        let lines = lrcData.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("["), let bracketEnd = line.firstIndex(of: "]") {
                let timeString = String(line[line.index(after: line.startIndex)..<bracketEnd])
                let text = String(line[line.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)
                let timeParts = timeString.components(separatedBy: ":")
                if timeParts.count == 2, let min = Double(timeParts[0]), let sec = Double(timeParts[1]) {
                    if !text.isEmpty { parsed.append(LyricLine(time: (min * 60) + sec, text: text)) }
                }
            }
        }
        DispatchQueue.main.async { self.lyrics = parsed }
    }
    
    // ⚡️ THE MISSING FUNCTION THAT BROKE THE BUILD
    func updateActiveLyric() {
        guard !lyrics.isEmpty else { return }
        if let idx = lyrics.lastIndex(where: { $0.time <= self.currentTime + 0.3 }), self.activeLyricIndex != idx {
            self.activeLyricIndex = idx
        }
    }
}
