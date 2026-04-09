import SwiftUI
import Combine
import AppKit

struct LRCTrack: Codable {
    let trackName: String?
    let artistName: String?
    let syncedLyrics: String?
}

struct LyricLine: Equatable {
    let time: Double
    let text: String
}

struct PlaylistTrack: Identifiable, Equatable {
    var id: String { title + artist }
    let title: String
    let artist: String
    let imageURL: String?
}

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    private var internalSongIdentifier: String = ""
    
    @Published var artworkURL: URL? = nil
    @Published var artworkDominantColor: Color = .green
    @Published var isPlaying: Bool = false
    @Published var loopMode: Int = 0
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 1.0
    
    @Published var lyrics: [LyricLine] = []
    @Published var activeLyricIndex: Int = 0
    @Published var isSearchingLyrics: Bool = false
    @Published var playlist: [PlaylistTrack] = []
    
    var timer: Timer?
    private var isFetching = false
    private var lastFetchTime = Date(timeIntervalSince1970: 0)
    private var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    
    private var lastActiveBrowser: String? = nil
    private var lastWindowIndex: Int? = nil
    private var lastTabIndex: Int? = nil
    
    let supportedBrowsers = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Safari"]
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
    }
    
    private func fetchDominantColor(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            let color = image.averageColor
            DispatchQueue.main.async { self.artworkDominantColor = color }
        }.resume()
    }
    
    // MARK: - STRICT LYRICS VERIFICATION ENGINE
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
    
    private func executeSearchFallback(title: String, artist: String) {
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
    
    private func isStrictMatch(apiTitle: String, apiArtist: String, targetTitle: String, targetArtist: String) -> Bool {
        let t1 = apiTitle.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let t2 = targetTitle.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let a1 = apiArtist.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let a2 = targetArtist.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
        let titleMatch = t1.contains(t2) || t2.contains(t1) || t1 == t2
        let artistMatch = a1.contains(a2) || a2.contains(a1) || a1 == a2 || a2.isEmpty || a1.isEmpty
        if targetTitle.lowercased().contains("cover") { return titleMatch }
        return titleMatch && artistMatch
    }
    
    private func parseLRC(_ lrcData: String) {
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
    
    func updateActiveLyric() {
        guard !lyrics.isEmpty else { return }
        if let idx = lyrics.lastIndex(where: { $0.time <= self.currentTime + 0.3 }), self.activeLyricIndex != idx { self.activeLyricIndex = idx }
    }
    
    // MARK: - APPLESCRIPT COMPILER
    private func buildAppleScript(browser: String, jsCode: String, wIdx: Int? = nil, tIdx: Int? = nil) -> String {
        let escapedJS = jsCode.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        if let w = wIdx, let t = tIdx {
            if browser == "Safari" {
                return "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(t) of window \(w) to return do JavaScript \"\(escapedJS)\"\nend timeout\nend try\nend tell\nreturn \"NOT_PLAYING\"\n" // ⚡️ Modified fallback
            } else {
                return "tell application \"\(browser)\"\ntry\nwith timeout of 1 second\ntell tab \(t) of window \(w) to return execute javascript \"\(escapedJS)\"\nend timeout\nend try\nend tell\nreturn \"NOT_PLAYING\"\n"
            }
        } else {
            if browser == "Safari" {
                return "tell application \"Safari\"\nset wCount to count of windows\nrepeat with wIdx from 1 to wCount\nset tCount to count of tabs of window wIdx\nrepeat with tIdx from 1 to tCount\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab tIdx of window wIdx to set tabResult to do JavaScript \"\(escapedJS)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & wIdx & \"|||\" & tIdx\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_PLAYING\""
            } else {
                return "tell application \"\(browser)\"\nset wCount to count of windows\nrepeat with wIdx from 1 to wCount\nset tCount to count of tabs of window wIdx\nrepeat with tIdx from 1 to tCount\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab tIdx of window wIdx to set tabResult to execute javascript \"\(escapedJS)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & wIdx & \"|||\" & tIdx\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_PLAYING\""
            }
        }
    }
    
    // MARK: - MEDIA CONTROLS
    func playTrack(_ track: PlaylistTrack) {
        DispatchQueue.global(qos: .userInitiated).async {
            let safeTitle = track.title.replacingOccurrences(of: "'", with: "\\'")
            let jsCode = """
            (function() {
                var targetTitle = '\(safeTitle)';
                var host = window.location.hostname;
                if (host.includes('music.youtube.com')) {
                    var qItems = document.querySelectorAll('ytmusic-player-queue-item');
                    for(var i=0; i<qItems.length; i++) {
                        var tN = qItems[i].querySelector('.song-title, .title, yt-formatted-string[title]');
                        var text = tN ? (tN.innerText || tN.getAttribute('title') || '').trim() : '';
                        if (text === targetTitle) {
                            var playBtn = qItems[i].querySelector('ytmusic-play-button-renderer') || qItems[i].querySelector('#play-button');
                            if (playBtn) { playBtn.click(); } else { qItems[i].dispatchEvent(new MouseEvent('dblclick', {bubbles: true, cancelable: true, view: window})); }
                            return 'PLAYED';
                        }
                    }
                }
                return 'NOT_PLAYING';
            })();
            """
            
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: browser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                _ = NSAppleScript(source: fastScript)?.executeAndReturnError(nil)
            }
            self.triggerFastFetch()
        }
    }
    
    func skipBackward() {
        if lastActiveBrowser == "SpotifyNative" {
            DispatchQueue.global(qos: .userInitiated).async {
                if self.currentTime > 3.0 { _ = NSAppleScript(source: "tell application \"Spotify\"\nset player position to 0\nplay\nend tell")?.executeAndReturnError(nil)
                } else { _ = NSAppleScript(source: "tell application \"Spotify\" to previous track")?.executeAndReturnError(nil) }
                DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch()
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var host = window.location.hostname; var active = null; if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (media[i].duration > 1) { active = media[i]; break; } } } if (active) { if (active.currentTime > 3 || active.ended || (active.duration > 0 && active.duration - active.currentTime < 1.5)) { active.currentTime = 0; active.play(); return 'RESTARTED'; } } return 'NOT_PLAYING'; })();"
            
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: browser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, res == "RESTARTED" {
                    DispatchQueue.main.async { self.currentTime = 0.0; self.isPlaying = true; self.updateActiveLyric() }; self.triggerFastFetch(); return
                }
            }
            self.sendMediaKey(key: 18); DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch()
        }
    }
    
    func togglePlayPause() {
        if lastActiveBrowser == "SpotifyNative" {
            DispatchQueue.global(qos: .userInitiated).async { _ = NSAppleScript(source: "tell application \"Spotify\" to playpause")?.executeAndReturnError(nil); DispatchQueue.main.async { self.isPlaying.toggle() }; self.triggerFastFetch() }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // ⚡️ FIX: Updated Spotify domain check and added 'NOT_PLAYING' loop-continuation fallback
            let jsCode = "(function() { var host = window.location.hostname; if (host.includes('music.youtube.com')) { var playBtn = document.querySelector('#play-pause-button'); if (playBtn) { playBtn.click(); return 'TOGGLED'; } } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=\"control-button-playpause\"]'); if (spotBtn) { spotBtn.click(); return 'TOGGLED'; } } var active = null; if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (media[i].duration > 1) { active = media[i]; break; } } if(!active && media.length > 0) active = media[0]; } if (active) { if (active.paused || active.ended) { active.play(); return 'PLAYED'; } else { active.pause(); return 'PAUSED'; } } return 'NOT_PLAYING'; })();"
            
            // ⚡️ Fast Path: Try hitting the exact tab we last saw
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: browser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, (res == "PLAYED" || res == "PAUSED" || res == "TOGGLED") {
                    DispatchQueue.main.async { if res == "TOGGLED" { self.isPlaying.toggle() } else { self.isPlaying = (res == "PLAYED") } }
                    self.triggerFastFetch(); return
                }
            }
            
            // ⚡️ Deep Scan Path: If tab changed, scan all tabs to find the music and pause it
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                if let res = result {
                    let action = res.components(separatedBy: "|||").first ?? ""
                    if action == "PLAYED" || action == "PAUSED" || action == "TOGGLED" {
                        DispatchQueue.main.async { if action == "TOGGLED" { self.isPlaying.toggle() } else { self.isPlaying = (action == "PLAYED") } }
                        self.triggerFastFetch()
                        return
                    }
                }
                // Absolute fallback
                self.sendMediaKey(key: 16); DispatchQueue.main.async { self.isPlaying.toggle() }; self.triggerFastFetch()
            }
        }
    }
    
    func skipForward() {
        if lastActiveBrowser == "SpotifyNative" {
            DispatchQueue.global(qos: .userInitiated).async { _ = NSAppleScript(source: "tell application \"Spotify\" to next track")?.executeAndReturnError(nil); DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch() }
            return
        }
        sendMediaKey(key: 17); DispatchQueue.main.async { self.currentTime = 0.0 }; triggerFastFetch()
    }
    
    private func triggerFastFetch() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.isFetching = false; self.fetchTitle() } }
    
    private func sendMediaKey(key: Int32) {
        let dataDown = Int((key << 16) | 0xa00); let dataUp = Int((key << 16) | 0xb00)
        let evDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xa00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataDown, data2: -1)
        let evUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xb00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataUp, data2: -1)
        evDown?.cgEvent?.post(tap: .cghidEventTap); evUp?.cgEvent?.post(tap: .cghidEventTap)
    }
    
    func seek(to percentage: Double) {
        DispatchQueue.main.async { self.currentTime = self.duration * percentage; self.updateActiveLyric() }
        if lastActiveBrowser == "SpotifyNative" {
            DispatchQueue.global(qos: .userInitiated).async { let script = "tell application \"Spotify\"\nset dur to (duration of current track) / 1000\nset player position to dur * \(percentage)\nend tell"; _ = NSAppleScript(source: script)?.executeAndReturnError(nil); self.triggerFastFetch() }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { function pt(str) { if(!str) return 0; var p = str.split(':'); var s = 0; var m = 1; while (p.length > 0) { s += m * parseInt(p.pop(), 10); m *= 60; } return s; } var percentage = \(percentage); var host = window.location.hostname; var active = null; if (host.includes('music.youtube.com')) { active = document.querySelector('.html5-main-video'); var ytmTime = document.querySelector('.time-info.ytmusic-player-bar'); if (active && ytmTime) { var p = ytmTime.innerText.split('/'); if (p.length === 2) { var localCurr = pt(p[0].trim()); var localDur = pt(p[1].trim()); if (localDur > 0) { var offset = active.currentTime - localCurr; active.currentTime = offset + (localDur * percentage); return 'SEEKED'; } } } } if (host.includes('youtube.com') && !host.includes('music.youtube.com')) { active = document.querySelector('.html5-main-video'); } else if (!host.includes('music.youtube.com')) { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (media[i].duration > 1) { active = media[i]; break; } } } if (active && active.duration) { active.currentTime = active.duration * percentage; return 'SEEKED'; } return 'NOT_PLAYING'; })();"
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: browser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, res == "SEEKED" { self.triggerFastFetch(); return }
            }
            if let script = NSAppleScript(source: self.buildAppleScript(browser: "Safari", jsCode: jsCode)) { _ = script.executeAndReturnError(nil) }
            self.triggerFastFetch()
        }
    }
    
    func toggleLoop() {
        DispatchQueue.main.async { self.lastLoopToggleTime = Date(); self.loopMode = (self.loopMode + 1) % 3 }
        if lastActiveBrowser == "SpotifyNative" {
            DispatchQueue.global(qos: .userInitiated).async { let script = "tell application \"Spotify\"\nset repeating to not repeating\nif repeating then\nreturn \"ALL\"\nelse\nreturn \"NONE\"\nend if\nend tell"; if let result = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue { DispatchQueue.main.async { if result == "ALL" { self.loopMode = 1 } else { self.loopMode = 0 } } } }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var host = window.location.hostname; if (host.includes('music.youtube.com')) { var btns = document.querySelectorAll('ytmusic-player-bar button'); var repeatBtn = null; for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { repeatBtn = btns[i]; break; } } if (repeatBtn) { repeatBtn.click(); return 'TOGGLED'; } return 'NOT_PLAYING'; } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=\"control-button-repeat\"]'); if (spotBtn) { spotBtn.click(); return 'TOGGLED'; } } else if (host.includes('music.apple.com')) { var appleBtn = document.querySelector('.button-repeat') || document.querySelector('[data-testid=\"repeat-button\"]'); if (appleBtn) { appleBtn.click(); return 'TOGGLED'; } } else if (host.includes('youtube.com')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) { yt.loop = !yt.loop; if(yt.loop) yt.setAttribute('loop', ''); else yt.removeAttribute('loop'); return yt.loop ? 'ALL' : 'NONE'; } } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { media[i].loop = !media[i].loop; return media[i].loop ? 'ALL' : 'NONE'; } } } return 'NOT_PLAYING'; })();"
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: browser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let result = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, result != "NOT_PLAYING" {
                    DispatchQueue.main.async { if result == "ALL" { self.loopMode = 1 } else if result == "NONE" { self.loopMode = 0 } }; return
                }
            }
            if let script = NSAppleScript(source: self.buildAppleScript(browser: "Safari", jsCode: jsCode)) { _ = script.executeAndReturnError(nil) }
        }
    }
    
    // MARK: - THE MAIN FETCH ENGINE
    func fetchTitle() {
        if isFetching { if Date().timeIntervalSince(lastFetchTime) > 3.0 { isFetching = false } else { return } }
        isFetching = true
        lastFetchTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            var isSpotifyNativeRunning = false
            
            for app in runningApps {
                if let name = app.localizedName {
                    if self.supportedBrowsers.contains(name) { activeBrowsers.append(name) }
                    if name == "Spotify" { isSpotifyNativeRunning = true }
                }
            }
            
            if isSpotifyNativeRunning {
                let spotScript = """
                tell application "Spotify"
                    if player state is playing then
                        set tName to name of current track
                        set tArtist to artist of current track
                        try
                            set tArt to artwork url of current track
                        on error
                            set tArt to "NO_IMAGE"
                        end try
                        set tPos to player position
                        set tDur to (duration of current track) / 1000
                        set rep to repeating
                        if rep then
                            set loopState to "ALL"
                        else
                            set loopState to "NONE"
                        end if
                        return tName & "|||" & tArtist & "|||" & tArt & "|||" & loopState & "|||" & tPos & "|||" & tDur
                    end if
                end tell
                return "NOT_PLAYING"
                """
                if let res = NSAppleScript(source: spotScript)?.executeAndReturnError(nil).stringValue, res != "NOT_PLAYING", res != "NOT_FOUND" {
                    self.parseAndApplyResult(result: res + "|||Queue unavailable for Spotify Native", browser: "SpotifyNative")
                    return
                }
            }
            
            if activeBrowsers.isEmpty { DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }; return }
            if let last = self.lastActiveBrowser, activeBrowsers.contains(last) {
                activeBrowsers.removeAll(where: { $0 == last })
                activeBrowsers.insert(last, at: 0)
            }
            
            // ⚡️ FIX: Updated Spotify check and tightened up the Playback State logic
            let jsCode = "(function(){function pt(str){if(!str)return 0;var p=str.split(':');var s=0,m=1;while(p.length>0){s+=m*parseInt(p.pop(),10);m*=60;}return s;}var host=window.location.hostname;var active=null;var cTitle='',cArtist='',cImg='NO_IMAGE',cCurr=-1,cDur=-1,loopState='NONE',playlist='';if(host.includes('music.youtube.com')){active=document.querySelector('.html5-main-video');var tEl=document.querySelector('ytmusic-player-bar .title');var aEl=document.querySelector('ytmusic-player-bar .byline');if(tEl)cTitle=tEl.innerText;if(aEl)cArtist=aEl.innerText.split('•')[0].trim();var time=document.querySelector('.time-info.ytmusic-player-bar');if(time){var p=time.innerText.split('/');if(p.length===2){cCurr=pt(p[0]);cDur=pt(p[1]);}}try{var qItems=document.querySelectorAll('ytmusic-player-queue-item');var pArr=[];var start=0;for(var i=0;i<qItems.length;i++){if(qItems[i].hasAttribute('selected')||qItems[i].getAttribute('play-button-state')==='playing'){start=i;break;}}for(var j=start;j<qItems.length;j++){var tN=qItems[j].querySelector('.song-title, .title, yt-formatted-string[title]');var aN=qItems[j].querySelector('.byline');var iN=qItems[j].querySelector('img');var tText=tN?(tN.innerText||tN.getAttribute('title')||'').trim():'';var aText=aN?aN.innerText.replace(/\\n/g,'').trim():'Unknown';var iSrc=iN?(iN.src||''):'NO_IMAGE';if(tText){pArr.push(tText+'~~~'+aText+'~~~'+iSrc);}if(pArr.length>=15)break;}playlist=pArr.join('&&&');}catch(e){}}else if(host.includes('spotify.com')){active=document.querySelector('video, audio');var tEl=document.querySelector('[data-testid=context-item-info-title]');var aEl=document.querySelector('[data-testid=context-item-info-artist]');if(tEl)cTitle=tEl.innerText;if(aEl)cArtist=aEl.innerText;var cEl=document.querySelector('[data-testid=playback-position]');var dEl=document.querySelector('[data-testid=playback-duration]');if(cEl)cCurr=pt(cEl.innerText);if(dEl)cDur=pt(dEl.innerText);}else if(host.includes('youtube.com')){active=document.querySelector('.html5-main-video');loopState=(active&&(active.loop||active.hasAttribute('loop')))?'ALL':'NONE';if(active&&active.duration>0.05){cDur=active.duration-0.05;}var attrTitle=document.querySelector('.ytVideoAttributeViewModelTitle')||document.querySelector('#title h1 yt-formatted-string');var attrArtist=document.querySelector('.ytVideoAttributeViewModelSubtitle')||document.querySelector('#owner-name a');if(attrTitle)cTitle=attrTitle.innerText.trim();if(attrArtist)cArtist=attrArtist.innerText.trim();try{var ytdItems=document.querySelectorAll('ytd-playlist-panel-video-renderer');var ytdArr=[];var ytdStart=0;for(var k=0;k<ytdItems.length;k++){if(ytdItems[k].hasAttribute('selected')){ytdStart=k;break;}}for(var l=ytdStart;l<ytdItems.length;l++){var yT=ytdItems[l].querySelector('#video-title');var yA=ytdItems[l].querySelector('#byline');var yI=ytdItems[l].querySelector('img');var iSrc=yI?(yI.src||''):'NO_IMAGE';if(yT&&yT.innerText.trim()){ytdArr.push(yT.innerText.trim()+'~~~'+(yA?yA.innerText.trim():'Unknown')+'~~~'+iSrc);}if(ytdArr.length>=15)break;}playlist=ytdArr.join('&&&');}catch(e){}}else{var media=document.querySelectorAll('video, audio');for(var i=0;i<media.length;i++){if(!media[i].paused&&media[i].currentTime>0){active=media[i];break;}}if(!active && media.length > 0) active = media[0];}var isPlaying=(active&&!active.paused&&!active.ended&&active.currentTime>0);if(!isPlaying&&navigator.mediaSession&&navigator.mediaSession.playbackState==='playing')isPlaying=true;if(isPlaying){var title=cTitle||document.title;var artist=cArtist||'EMPTY_ARTIST';var curr=cCurr!==-1?cCurr:(active?active.currentTime:0);var dur=cDur!==-1&&isNaN(cDur)===false&&cDur!==0?cDur:(active?(active.duration||1):1);if(navigator.mediaSession&&navigator.mediaSession.metadata){var m=navigator.mediaSession.metadata;if(!cTitle&&m.title)title=m.title;if(artist==='EMPTY_ARTIST'&&m.artist)artist=m.artist;if(cImg==='NO_IMAGE'&&m.artwork&&m.artwork.length>0)cImg=m.artwork[m.artwork.length-1].src;}return title+'|||'+artist+'|||'+cImg+'|||'+loopState+'|||'+curr+'|||'+dur+'|||'+playlist;}return 'NOT_PLAYING';})();"
            
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                if let res = result {
                    self.parseAndApplyResult(result: res, browser: res.components(separatedBy: "|||").last ?? "Unknown")
                } else {
                    DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }
                }
            }
        }
    }

    private func runFullAppleScriptLoop(jsCode: String, completion: @escaping (String?) -> Void) {
        let runningApps = NSWorkspace.shared.runningApplications
        let browsers = runningApps.filter { supportedBrowsers.contains($0.localizedName ?? "") }
        for app in browsers {
            if let name = app.localizedName {
                let script = self.buildAppleScript(browser: name, jsCode: jsCode)
                if let result = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue {
                    if result != "NOT_PLAYING" {
                        completion(result + "|||" + name); return
                    }
                }
            }
        }
        completion(nil)
    }

    private func parseAndApplyResult(result: String, browser: String) {
        DispatchQueue.main.async {
            let components = result.components(separatedBy: "|||")
            guard components.count >= 6 else { self.isFetching = false; return }
            
            self.isPlaying = true
            let rawTitle = components[0].replacingOccurrences(of: " - YouTube Music", with: "").replacingOccurrences(of: " - YouTube", with: "").replacingOccurrences(of: " | Spotify", with: "")
            let rawArtist = components[1] == "EMPTY_ARTIST" ? "" : components[1]
            let imgString = components[2]
            let loopString = components[3]
            let currString = components[4]
            let durString = components[5]
            
            var playlistString = ""
            if components.count >= 7 { playlistString = components[6] }
            
            if browser == "SpotifyNative" {
                self.lastActiveBrowser = "SpotifyNative"
                self.lastWindowIndex = nil
                self.lastTabIndex = nil
            } else if components.count >= 9 {
                self.lastActiveBrowser = browser
                self.lastWindowIndex = Int(components[7])
                self.lastTabIndex = Int(components[8])
            }
            
            // ⚡️ ADVANCED FUZZY MATCH DEDUPLICATION
            let trackStrings = playlistString.components(separatedBy: "&&&")
            var uniqueTracks: [PlaylistTrack] = []
            
            for s in trackStrings {
                if s.isEmpty { continue }
                let parts = s.components(separatedBy: "~~~")
                let t = parts[0]
                let a = parts.count > 1 ? parts[1] : "Unknown"
                
                var img = parts.count > 2 ? parts[2] : ""
                if img.hasPrefix("http://") { img = img.replacingOccurrences(of: "http://", with: "https://") }
                
                let cleanNewTitle = t.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
                
                let isDuplicate = uniqueTracks.contains { existing in
                    let cleanExistingTitle = existing.title.lowercased().components(separatedBy: .alphanumerics.inverted).joined()
                    if cleanNewTitle.isEmpty || cleanExistingTitle.isEmpty { return false }
                    return cleanExistingTitle.contains(cleanNewTitle) || cleanNewTitle.contains(cleanExistingTitle)
                }
                
                if !isDuplicate {
                    uniqueTracks.append(PlaylistTrack(title: t, artist: a, imageURL: img))
                }
            }
            self.playlist = uniqueTracks
            
            let identifier = rawTitle + rawArtist
            if self.internalSongIdentifier != identifier {
                self.internalSongIdentifier = identifier
                self.fetchLyricsEngine(title: rawTitle, artist: rawArtist)
                self.currentTime = 0.0
            }
            
            let displayString = rawArtist.isEmpty ? rawTitle : "\(rawTitle) - \(rawArtist)"
            if self.currentSong != displayString { self.currentSong = displayString }
            
            if imgString != "NO_IMAGE", let url = URL(string: imgString) {
                if self.artworkURL != url { self.artworkURL = url; self.fetchDominantColor(from: url) }
            } else {
                self.artworkURL = nil
                self.artworkDominantColor = .green
            }
            
            let newTime = Double(currString) ?? 0.0
            if abs(self.currentTime - newTime) > 1.5 { self.currentTime = newTime }
            self.duration = Double(durString) ?? 1.0
            
            if Date().timeIntervalSince(self.lastLoopToggleTime) > 2.0 {
                if loopString == "ALL" { self.loopMode = 1 } else if loopString == "ONE" { self.loopMode = 2 } else { self.loopMode = 0 }
            }
            self.isFetching = false
        }
    }
}
