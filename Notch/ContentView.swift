import SwiftUI
import Combine
import AppKit

// ⚡️ NSIMAGE EXTENSION: Extracts the dominant color from the album artwork
extension NSImage {
    var averageColor: Color {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .green }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rgba = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return .green }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        // Boost brightness slightly so dark albums don't create an invisible black waveform
        var r = CGFloat(rgba[0]) / 255.0
        var g = CGFloat(rgba[1]) / 255.0
        var b = CGFloat(rgba[2]) / 255.0
        let maxColor = max(r, max(g, b))
        if maxColor < 0.4 {
            let boost = 0.4 - maxColor
            r += boost; g += boost; b += boost
        }
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }
}

// ⚡️ THE SECRET SAUCE: Custom S-Curve Notch Shape
struct DynamicNotchShape: Shape {
    var cornerRadius: CGFloat
    var blendRadius: CGFloat = 16 // The size of the concave "swoop" at the top
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: blendRadius, y: blendRadius), control: CGPoint(x: blendRadius, y: 0))
        path.addLine(to: CGPoint(x: blendRadius, y: rect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: blendRadius + cornerRadius, y: rect.maxY), control: CGPoint(x: blendRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - blendRadius - cornerRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - blendRadius, y: rect.maxY - cornerRadius), control: CGPoint(x: rect.maxX - blendRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - blendRadius, y: blendRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0), control: CGPoint(x: rect.maxX - blendRadius, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        return path
    }
}

struct WaveformView: View {
    var isPlaying: Bool
    var color: Color // ⚡️ Now accepts the dynamically extracted color
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(isPlaying ? color : Color.gray.opacity(0.5))
                    .frame(width: 3, height: isPlaying ? (isAnimating ? .random(in: 6...14) : 4) : 4)
                    .animation(
                        isPlaying ? Animation.easeInOut(duration: 0.3).repeatForever().delay(Double(index) * 0.1) : .easeOut(duration: 0.2),
                        value: isAnimating
                    )
            }
        }
        .onChange(of: isPlaying) { playing in isAnimating = playing }
        .onAppear { if isPlaying { isAnimating = true } }
    }
}

struct LRCTrack: Codable {
    let trackName: String?
    let artistName: String?
    let syncedLyrics: String?
}

struct LyricLine: Equatable {
    let time: Double
    let text: String
}

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    private var internalSongIdentifier: String = ""
    
    @Published var artworkURL: URL? = nil
    @Published var artworkDominantColor: Color = .green // ⚡️ Stores the extracted color
    @Published var isPlaying: Bool = false
    @Published var loopMode: Int = 0
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 1.0
    
    @Published var lyrics: [LyricLine] = []
    @Published var activeLyricIndex: Int = 0
    @Published var isSearchingLyrics: Bool = false
    
    var timer: Timer?
    private var isFetching = false
    private var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    
    private var lastActiveBrowser: String? = nil
    private var lastWindowIndex: Int? = nil
    private var lastTabIndex: Int? = nil
    
    let supportedBrowsers = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Safari"]
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
    }
    
    // ⚡️ Fetches the image behind the scenes and calculates the average color
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
        if let idx = lyrics.lastIndex(where: { $0.time <= self.currentTime }), self.activeLyricIndex != idx { self.activeLyricIndex = idx }
    }
    
    // MARK: - MEDIA CONTROLS
    let NX_KEYTYPE_PLAY: Int32 = 16
    let NX_KEYTYPE_NEXT: Int32 = 17
    let NX_KEYTYPE_PREVIOUS: Int32 = 18
    
    func skipBackward() { sendMediaKey(key: NX_KEYTYPE_PREVIOUS); DispatchQueue.main.async { self.currentTime = 0.0 }; triggerFastFetch() }
    func togglePlayPause() { sendMediaKey(key: NX_KEYTYPE_PLAY); DispatchQueue.main.async { self.isPlaying.toggle() }; triggerFastFetch() }
    func skipForward() { sendMediaKey(key: NX_KEYTYPE_NEXT); DispatchQueue.main.async { self.currentTime = 0.0 }; triggerFastFetch() }
    
    private func triggerFastFetch() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.isFetching = false; self.fetchTitle() } }
    
    private func sendMediaKey(key: Int32) {
        let dataDown = Int((key << 16) | 0xa00)
        let dataUp = Int((key << 16) | 0xb00)
        let evDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xa00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataDown, data2: -1)
        let evUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xb00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataUp, data2: -1)
        evDown?.cgEvent?.post(tap: .cghidEventTap)
        evUp?.cgEvent?.post(tap: .cghidEventTap)
    }
    
    func seek(to percentage: Double) {
        DispatchQueue.main.async { self.currentTime = self.duration * percentage; self.updateActiveLyric() }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var percentage = \(percentage); var host = window.location.hostname; var active = null; if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { active = media[i]; break; } } } if (active && active.duration) { active.currentTime = active.duration * percentage; return 'SEEKED'; } return 'NOT_FOUND'; })();"
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = browser == "Safari" ? "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return do JavaScript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return execute javascript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\""
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, res == "SEEKED" { self.triggerFastFetch(); return }
            }
            self.runFullAppleScriptLoop(jsCode: jsCode) { _ in }; self.triggerFastFetch()
        }
    }
    
    func toggleLoop() {
        DispatchQueue.main.async { self.lastLoopToggleTime = Date(); self.loopMode = (self.loopMode + 1) % 3 }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var host = window.location.hostname; if (host.includes('music.youtube.com')) { var btns = document.querySelectorAll('ytmusic-player-bar button'); var repeatBtn = null; for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { repeatBtn = btns[i]; break; } } if (repeatBtn) { repeatBtn.click(); return 'TOGGLED'; } return 'NOT_FOUND'; } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=control-button-repeat]'); if (spotBtn) { spotBtn.click(); return 'TOGGLED'; } } else if (host.includes('music.apple.com')) { var appleBtn = document.querySelector('.button-repeat') || document.querySelector('[data-testid=repeat-button]'); if (appleBtn) { appleBtn.click(); return 'TOGGLED'; } } else if (host.includes('youtube.com')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) { yt.loop = !yt.loop; if(yt.loop) yt.setAttribute('loop', ''); else yt.removeAttribute('loop'); return yt.loop ? 'ALL' : 'NONE'; } } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { media[i].loop = !media[i].loop; return media[i].loop ? 'ALL' : 'NONE'; } } } return 'NOT_FOUND'; })();"
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = browser == "Safari" ? "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return do JavaScript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return execute javascript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\""
                if let result = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, result != "NOT_FOUND" {
                    DispatchQueue.main.async { if result == "ALL" { self.loopMode = 1 } else if result == "NONE" { self.loopMode = 0 } }
                    return
                }
            }
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in DispatchQueue.main.async { if result == "ALL" { self.loopMode = 1 } else if result == "NONE" { self.loopMode = 0 } } }
        }
    }
    
    // MARK: - FETCH LOGIC WITH YT METADATA EXTRACTION
    func fetchTitle() {
        guard !isFetching else { return }
        isFetching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            for app in runningApps { if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) } }
            if activeBrowsers.isEmpty { DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }; return }
            
            if let last = self.lastActiveBrowser, activeBrowsers.contains(last) {
                activeBrowsers.removeAll(where: { $0 == last })
                activeBrowsers.insert(last, at: 0)
            }
            
            let jsCode = "(function() { var host = window.location.hostname; var isPlaying = false; var loopState = 'NONE'; var active = null; var cTitle = ''; var cArtist = ''; if (host.includes('music.youtube.com')) { active = document.querySelector('.html5-main-video'); if (active && !active.paused && active.currentTime > 0) isPlaying = true; var btns = document.querySelectorAll('ytmusic-player-bar button'); for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { if (lbl.includes('1') || lbl.includes('one') || lbl.includes('una') || lbl.includes('곡')) { loopState = 'ONE'; } else if (!lbl.includes('off') && !lbl.includes('안함') && !lbl.includes('desactiv')) { loopState = 'ALL'; } else { loopState = 'NONE'; } break; } } var tEl = document.querySelector('ytmusic-player-bar .title'); var aEl = document.querySelector('ytmusic-player-bar .byline'); if (tEl) cTitle = tEl.innerText; if (aEl) cArtist = aEl.innerText.split('•')[0].trim(); } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=control-button-repeat]'); if (spotBtn) { var checked = spotBtn.getAttribute('aria-checked'); if (checked === 'mixed') loopState = 'ONE'; else if (checked === 'true') loopState = 'ALL'; else loopState = 'NONE'; } } else if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); if (active && !active.paused && active.currentTime > 0) { isPlaying = true; loopState = (active.loop || active.hasAttribute('loop')) ? 'ALL' : 'NONE'; var attrTitle = document.querySelector('.ytVideoAttributeViewModelTitle'); var attrArtist = document.querySelector('.ytVideoAttributeViewModelSubtitle'); if (attrTitle) cTitle = attrTitle.innerText.trim(); if (attrArtist) cArtist = attrArtist.innerText.trim(); if (!cTitle) { var rows = document.querySelectorAll('ytd-info-row-renderer, ytd-metadata-row-renderer'); for(var j=0; j<rows.length; j++) { var txt = rows[j].innerText.toLowerCase(); if(txt.includes('song') || txt.includes('노래')) cTitle = rows[j].querySelector('#content')?.innerText || cTitle; if(txt.includes('artist') || txt.includes('아티스트')) cArtist = rows[j].querySelector('#content')?.innerText || cArtist; } } } } else if (!host.includes('music.apple.com')) { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { active = media[i]; isPlaying = true; loopState = active.loop ? 'ALL' : 'NONE'; break; } } } if (!isPlaying && navigator.mediaSession && navigator.mediaSession.playbackState === 'playing') { isPlaying = true; } if (isPlaying) { var title = cTitle || document.title; var artist = cArtist; var img = 'NO_IMAGE'; var curr = 0; var dur = 1; if (active) { curr = active.currentTime; dur = active.duration || 1; } if (navigator.mediaSession && navigator.mediaSession.metadata) { var m = navigator.mediaSession.metadata; if(!cTitle && m.title) title = m.title; if(!cArtist && m.artist) artist = m.artist; if(m.artwork && m.artwork.length > 0) img = m.artwork[m.artwork.length - 1].src; } return title + '|||' + (artist ? artist : 'EMPTY_ARTIST') + '|||' + img + '|||' + loopState + '|||' + curr + '|||' + dur; } return 'NOT_PLAYING'; })();"
            
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = browser == "Safari" ? "tell application \"Safari\"\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & \"\(wIdx)\" & \"|||\" & \"\(tIdx)\"\nend if\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & \"\(wIdx)\" & \"|||\" & \"\(tIdx)\"\nend if\nend tell\nreturn \"NOT_FOUND\""
                
                if let result = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, result != "NOT_FOUND", result != "NOT_PLAYING" {
                    self.parseAndApplyResult(result: result, browser: browser); return
                } else {
                    self.lastActiveBrowser = nil; self.lastWindowIndex = nil; self.lastTabIndex = nil
                }
            }
            
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                if let res = result {
                    let parts = res.components(separatedBy: "|||")
                    if parts.count >= 8 { self.parseAndApplyResult(result: res, browser: parts.last!) }
                } else {
                    DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }
                }
            }
        }
    }
    
    private func runFullAppleScriptLoop(jsCode: String, completion: @escaping (String?) -> Void) {
        let runningApps = NSWorkspace.shared.runningApplications
        var activeBrowsers: [String] = []
        for app in runningApps { if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) } }
        
        for browser in activeBrowsers {
            let script = browser == "Safari" ? "tell application \"Safari\"\nset wCount to count of windows\nrepeat with wIdx from 1 to wCount\nset tCount to count of tabs of window wIdx\nrepeat with tIdx from 1 to tCount\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab tIdx of window wIdx to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & wIdx & \"|||\" & tIdx\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\nset wCount to count of windows\nrepeat with wIdx from 1 to wCount\nset tCount to count of tabs of window wIdx\nrepeat with tIdx from 1 to tCount\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab tIdx of window wIdx to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & wIdx & \"|||\" & tIdx\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
            
            if let result = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue, result != "NOT_FOUND", result != "NOT_PLAYING" {
                completion(result + "|||" + browser); return
            }
        }
        completion(nil)
    }
    
    private func parseAndApplyResult(result: String, browser: String) {
        DispatchQueue.main.async {
            self.isPlaying = true
            let components = result.components(separatedBy: "|||")
            
            let rawTitle = components[0].replacingOccurrences(of: " - YouTube Music", with: "").replacingOccurrences(of: " - YouTube", with: "").replacingOccurrences(of: " | Spotify", with: "")
            let rawArtist = components[1] == "EMPTY_ARTIST" ? "" : components[1]
            let imgString = components[2]
            let loopString = components[3]
            let currString = components[4]
            let durString = components[5]
            
            if components.count >= 8 {
                self.lastActiveBrowser = browser
                self.lastWindowIndex = Int(components[6])
                self.lastTabIndex = Int(components[7])
            }
            
            let identifier = rawTitle + rawArtist
            if self.internalSongIdentifier != identifier {
                self.internalSongIdentifier = identifier
                self.fetchLyricsEngine(title: rawTitle, artist: rawArtist)
            }
            
            let displayString = rawArtist.isEmpty ? rawTitle : "\(rawTitle) - \(rawArtist)"
            if self.currentSong != displayString { self.currentSong = displayString }
            
            if imgString != "NO_IMAGE", let url = URL(string: imgString) {
                if self.artworkURL != url {
                    self.artworkURL = url
                    self.fetchDominantColor(from: url)
                }
            } else {
                self.artworkURL = nil
                self.artworkDominantColor = .green
            }
            
            let newTime = Double(currString) ?? 0.0
            if abs(self.currentTime - newTime) > 2.0 { self.currentTime = newTime }
            self.duration = Double(durString) ?? 1.0
            
            if Date().timeIntervalSince(self.lastLoopToggleTime) > 2.0 {
                if loopString == "ALL" { self.loopMode = 1 } else if loopString == "ONE" { self.loopMode = 2 } else { self.loopMode = 0 }
            }
            self.isFetching = false
        }
    }
}

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    let localTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // ⚡️ TUNING CONSTANTS
    let notchHeight: CGFloat = 32
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let expandedHeight: CGFloat = !nowPlaying.lyrics.isEmpty ? 164 : 100

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                    .fill(Color.black)
                    .frame(width: isExpanded ? expandedWidth : collapsedWidth,
                           height: isExpanded ? expandedHeight : notchHeight)
                    .overlay(
                        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                            .stroke(Color.white.opacity(isExpanded ? 0.1 : 0.0), lineWidth: 1)
                    )

                // CONTENT STACK
                VStack(spacing: 0) {
                    if !isExpanded {
                        // ⚡️ COLLAPSED STATE
                        HStack(spacing: 0) {
                            // LEFT SIDE: Mini Album Art replacing the music note
                            Group {
                                if hasMedia && nowPlaying.artworkURL != nil {
                                    AsyncImage(url: nowPlaying.artworkURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: { Color.gray.opacity(0.3) }
                                    .frame(width: 20, height: 20)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                } else {
                                    Image(systemName: "music.note")
                                        .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .frame(width: 24, alignment: .leading)
                            
                            Spacer()
                            
                            // RIGHT SIDE: Waveform
                            WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor)
                                .frame(width: 24, alignment: .trailing)
                        }
                        .padding(.horizontal, 24)
                        .frame(height: notchHeight)
                        .transition(.opacity)
                        
                    } else {
                        // ⚡️ EXPANDED STATE
                        VStack(spacing: 8) {
                            // THE GAP
                            Color.clear.frame(height: notchHeight - 8)
                            
                            // TOP ROW (Controls)
                            HStack {
                                Group {
                                    if hasMedia && nowPlaying.artworkURL != nil {
                                        AsyncImage(url: nowPlaying.artworkURL) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: { Color.gray.opacity(0.3) }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        Image(systemName: "music.note")
                                            .foregroundColor(nowPlaying.isPlaying ? Color.red : Color.gray)
                                            .font(.system(size: 20, weight: .bold))
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hasMedia ? (nowPlaying.isPlaying ? "Now Playing" : "Paused") : "Waiting...")
                                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                                    Text(hasMedia ? nowPlaying.currentSong : "Nothing playing")
                                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                                }
                                .padding(.leading, 6)
                                
                                Spacer()
                                
                                if hasMedia {
                                    HStack(spacing: 12) {
                                        Button(action: { nowPlaying.skipBackward() }) { Image(systemName: "backward.fill").foregroundColor(.white) }.buttonStyle(.plain)
                                        Button(action: { nowPlaying.togglePlayPause() }) { Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill").foregroundColor(.white) }.buttonStyle(.plain)
                                        Button(action: { nowPlaying.skipForward() }) { Image(systemName: "forward.fill").foregroundColor(.white) }.buttonStyle(.plain)
                                        Button(action: { nowPlaying.toggleLoop() }) {
                                            Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat")
                                                .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // PROGRESS BAR
                            if hasMedia {
                                HStack(spacing: 8) {
                                    Text(formatTime(isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.2)).frame(height: 6)
                                            Capsule().fill(Color.white).frame(width: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : (nowPlaying.currentTime / nowPlaying.duration))), height: 6)
                                        }
                                        .gesture(DragGesture(minimumDistance: 0)
                                            .onChanged { v in isDragging = true; dragProgress = min(max(0, v.location.x / geo.size.width), 1) }
                                            .onEnded { v in nowPlaying.seek(to: min(max(0, v.location.x / geo.size.width), 1)); DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDragging = false } }
                                        )
                                    }.frame(height: 6)
                                    Text("-" + formatTime(nowPlaying.duration - (isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime)))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }.padding(.horizontal, 24)
                            }
                            
                            // LYRICS
                            if hasMedia && !nowPlaying.lyrics.isEmpty {
                                GeometryReader { geo in
                                    let itemHeight: CGFloat = 26
                                    let activeOffset = CGFloat(nowPlaying.activeLyricIndex) * itemHeight
                                    let centerAdjustment = (geo.size.height - itemHeight) / 2.0
                                    
                                    VStack(spacing: 0) {
                                        ForEach(Array(nowPlaying.lyrics.enumerated()), id: \.offset) { index, lyric in
                                            let distance = abs(index - nowPlaying.activeLyricIndex)
                                            Text(lyric.text)
                                                .font(.system(size: 14, weight: distance == 0 ? .bold : .semibold))
                                                .foregroundColor(distance == 0 ? .white : (distance == 1 ? .white.opacity(0.4) : .clear))
                                                .multilineTextAlignment(.center) // ⚡️ Forces pure center alignment
                                                .frame(maxWidth: expandedWidth - 48, alignment: .center)
                                                .frame(height: itemHeight)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .scaleEffect(distance == 0 ? 1.0 : 0.85).blur(radius: distance == 0 ? 0 : 0.3)
                                        }
                                    }
                                    .frame(width: geo.size.width, alignment: .center) // ⚡️ THE FIX: Forces VStack to center inside GeometryReader
                                    .offset(y: -activeOffset + centerAdjustment)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: nowPlaying.activeLyricIndex)
                                }
                                .frame(height: 52)
                                .clipped()
                                .mask(LinearGradient(gradient: Gradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15), .init(color: .black, location: 0.85), .init(color: .clear, location: 1)]), startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
                .frame(width: isExpanded ? expandedWidth : collapsedWidth,
                       height: isExpanded ? expandedHeight : notchHeight)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
            .onHover { h in isExpanded = h }
            
            Spacer()
        }
        .frame(width: expandedWidth, height: 200)
        .edgesIgnoringSafeArea(.all)
        .onReceive(localTimer) { _ in
            if nowPlaying.isPlaying && !isDragging {
                nowPlaying.currentTime += 1.0
                nowPlaying.updateActiveLyric()
            }
        }
    }
    
    private func formatTime(_ s: Double) -> String {
        let ts = Int(s); return String(format: "%d:%02d", ts / 60, ts % 60)
    }
}
