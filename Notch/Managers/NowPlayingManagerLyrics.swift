import Foundation

extension NowPlayingManager {
    
    // ⚡️ THE MASTER ENTRY POINT (Handles Caching & Debouncing)
    func fetchLyricsEngine(title: String, artist: String) {
        
        // 1. Generate a brand new, unique ticket for this specific search request
        let searchTicket = UUID()
        self.currentLyricSearchID = searchTicket
        
        // 2. Deep clean the title first so our cache keys are perfectly consistent
        var cleanTitle = title
            .replacingOccurrences(of: "(Official Video)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[Official Music Video]", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "(Lyrics)", with: "", options: .caseInsensitive)
        
        if let regex = try? NSRegularExpression(pattern: "(\\(|-)?\\s*(feat\\.|ft\\.|featuring).*?(\\)|$)", options: .caseInsensitive) {
            cleanTitle = regex.stringByReplacingMatches(in: cleanTitle, range: NSRange(cleanTitle.startIndex..., in: cleanTitle), withTemplate: "")
        }
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespaces)
        
        guard !cleanTitle.isEmpty else { return }
        
        let cacheKey = "\(cleanTitle.lowercased())-\(artist.lowercased())"
        
        // 3. CACHE CHECK
        if let cachedLyrics = self.lyricsCache[cacheKey] {
            print("💾 [Lyrics] CACHE HIT: Loaded '\(cleanTitle)' instantly from memory.")
            DispatchQueue.main.async {
                self.lyrics = cachedLyrics
                self.activeLyricIndex = 0
                self.isSearchingLyrics = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isSearchingLyrics = true
            self.lyrics = []
            self.activeLyricIndex = 0
        }
        
        // 4. THE BULLETPROOF TICKET DEBOUNCER
        lyricSearchTask?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // ⚡️ THE SANITY CHECK: Does this timer hold the newest ticket?
            guard self.currentLyricSearchID == searchTicket else {
                print("🛑 [Lyrics] Debouncer: A newer song was played. Aborting old search for '\(cleanTitle)'.")
                return
            }
            
            print("🔍 [Lyrics] Timer finished! Starting network waterfall for: '\(cleanTitle)' by '\(artist)'")
            // ⚡️ FIX 1: We pass the ticket down the waterfall!
            self.fetchLRCLibGet(title: cleanTitle, artist: artist, cacheKey: cacheKey, ticket: searchTicket)
        }
        
        lyricSearchTask = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
    
    // ---------------------------------------------------------
    // 🌐 SOURCE 1A: LRCLIB EXACT
    // ---------------------------------------------------------
    private func fetchLRCLibGet(title: String, artist: String, cacheKey: String, ticket: UUID) {
        guard !artist.isEmpty else {
            self.fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket); return
        }
        
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        
        guard let url = components?.url else { self.fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket); return }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        req.setValue("WaveNotch v1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: req) { data, _, err in
            // ⚡️ THE KILL SWITCH: Instantly abort if the user skipped the song during the network request
            guard self.currentLyricSearchID == ticket else { return }
            
            if err != nil {
                self.fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket); return
            }
            
            if let data = data, let track = try? JSONDecoder().decode(LRCTrack.self, from: data), let synced = track.syncedLyrics, !synced.isEmpty {
                print("✅ [Lyrics] SUCCESS: LRCLIB Exact Match!")
                self.saveAndPublish(lyricsText: synced, isSynced: true, cacheKey: cacheKey, ticket: ticket)
            } else {
                self.fetchLRCLibSearch(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            }
        }.resume()
    }
    
    // ---------------------------------------------------------
    // 🌐 SOURCE 1B: LRCLIB SEARCH (Fuzzy Match)
    // ---------------------------------------------------------
    private func fetchLRCLibSearch(title: String, artist: String, cacheKey: String, ticket: UUID) {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [ URLQueryItem(name: "q", value: query) ]
        
        guard let url = components?.url else { self.fetchOVH(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket); return }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        req.setValue("WaveNotch v1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard self.currentLyricSearchID == ticket else { return } // ⚡️ Kill Switch
            
            if let data = data, let tracks = try? JSONDecoder().decode([LRCTrack].self, from: data) {
                for track in tracks {
                    if let synced = track.syncedLyrics, !synced.isEmpty, self.isStrictMatch(apiTitle: track.trackName ?? "", apiArtist: track.artistName ?? "", targetTitle: title, targetArtist: artist) {
                        print("✅ [Lyrics] SUCCESS: LRCLIB Search Match!")
                        self.saveAndPublish(lyricsText: synced, isSynced: true, cacheKey: cacheKey, ticket: ticket)
                        return
                    }
                }
            }
            self.fetchOVH(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
        }.resume()
    }
    
    // ---------------------------------------------------------
    // 🌐 SOURCE 2: LYRICS.OVH (Western Pop/Rock)
    // ---------------------------------------------------------
    private func fetchOVH(title: String, artist: String, cacheKey: String, ticket: UUID) {
        guard !artist.isEmpty else { self.fetchNetease(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket); return }
        
        let eArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artist
        let eTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        let urlStr = "https://api.lyrics.ovh/v1/\(eArtist)/\(eTitle)"
        
        guard let url = URL(string: urlStr) else { self.fetchNetease(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket); return }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard self.currentLyricSearchID == ticket else { return } // ⚡️ Kill Switch
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lyricsText = json["lyrics"] as? String,
               !lyricsText.isEmpty {
                print("✅ [Lyrics] SUCCESS: OVH Fallback (Teleprompter Mode)")
                let cleanText = lyricsText.replacingOccurrences(of: "Paroles de la chanson", with: "")
                self.saveAndPublish(lyricsText: cleanText, isSynced: false, cacheKey: cacheKey, ticket: ticket)
            } else {
                self.fetchNetease(title: title, artist: artist, cacheKey: cacheKey, ticket: ticket)
            }
        }.resume()
    }
    
    // ---------------------------------------------------------
    // 🌐 SOURCE 3: NETEASE (Browser Spoofed)
    // ---------------------------------------------------------
    private func fetchNetease(title: String, artist: String, cacheKey: String, ticket: UUID) {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        var req = URLRequest(url: URL(string: "https://music.163.com/api/search/pc")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 4.0
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "s", value: query), URLQueryItem(name: "type", value: "1")]
        req.httpBody = bodyComponents.query?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard self.currentLyricSearchID == ticket else { return } // ⚡️ Kill Switch
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  let firstSong = songs.first,
                  let id = firstSong["id"] as? Int else {
                
                print("❌ [Lyrics] All lyric sources exhausted. No lyrics found.")
                DispatchQueue.main.async { self.isSearchingLyrics = false }
                return
            }
            
            let lyricUrl = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1")!
            var lReq = URLRequest(url: lyricUrl)
            lReq.timeoutInterval = 4.0
            lReq.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
            lReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            URLSession.shared.dataTask(with: lReq) { lData, _, _ in
                guard self.currentLyricSearchID == ticket else { return } // ⚡️ Kill Switch
                
                if let lData = lData,
                   let lJson = try? JSONSerialization.jsonObject(with: lData) as? [String: Any],
                   let lrc = lJson["lrc"] as? [String: Any],
                   let lyricText = lrc["lyric"] as? String,
                   !lyricText.isEmpty {
                    print("✅ [Lyrics] SUCCESS: Netease Cloud Music!")
                    self.saveAndPublish(lyricsText: lyricText, isSynced: true, cacheKey: cacheKey, ticket: ticket)
                } else {
                    print("❌ [Lyrics] All lyric sources exhausted. No lyrics found.")
                    DispatchQueue.main.async { self.isSearchingLyrics = false }
                }
            }.resume()
        }.resume()
    }
    
    // ---------------------------------------------------------
    // 🛠 THE CACHING PUBLISHER & PARSERS
    // ---------------------------------------------------------
    
    // ⚡️ Centralized function to parse, save to cache, and push to the UI
    private func saveAndPublish(lyricsText: String, isSynced: Bool, cacheKey: String, ticket: UUID) {
        guard self.currentLyricSearchID == ticket else { return } // ⚡️ Final Safety Net
        
        let parsedArray = isSynced ? parseLRC(lyricsText) : parseUnsynced(lyricsText)
        
        DispatchQueue.main.async {
            self.lyricsCache[cacheKey] = parsedArray // 💾 Save to memory for next time!
            self.lyrics = parsedArray
            self.isSearchingLyrics = false
        }
    }
    
    private func parseLRC(_ lrcData: String) -> [LyricLine] {
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
        return parsed
    }
    
    private func parseUnsynced(_ text: String) -> [LyricLine] {
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
        
        // ⚡️ FIX 2: Dropped offset from 0.3 to 0.05. It will now track exactly with the audio rather than jumping ahead!
        if let idx = lyrics.lastIndex(where: { $0.time <= self.currentTime + 0.05 }), self.activeLyricIndex != idx {
            self.activeLyricIndex = idx
        }
    }
}
