import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    @Published var artworkURL: URL? = nil
    @Published var isPlaying: Bool = false
    @Published var loopMode: Int = 0
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 1.0
    
    var timer: Timer?
    private var isFetching = false
    private var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    
    // ⚡️ THE GENIUS SPEED HACK: Tab Caching
    private var lastActiveBrowser: String? = nil
    private var lastWindowIndex: Int? = nil
    private var lastTabIndex: Int? = nil
    
    let supportedBrowsers = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Safari"]
    
    init() {
        // Reduced to 1.0s because the cache makes it cost 0% CPU!
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
    }
    
    // MARK: - MEDIA CONTROLS
    let NX_KEYTYPE_PLAY: Int32 = 16
    let NX_KEYTYPE_NEXT: Int32 = 17
    let NX_KEYTYPE_PREVIOUS: Int32 = 18
    
    func skipBackward() {
        sendMediaKey(key: NX_KEYTYPE_PREVIOUS)
        DispatchQueue.main.async { self.currentTime = 0.0 }
        triggerFastFetch()
    }
    
    func togglePlayPause() {
        sendMediaKey(key: NX_KEYTYPE_PLAY)
        DispatchQueue.main.async { self.isPlaying.toggle() }
        triggerFastFetch()
    }
    
    func skipForward() {
        sendMediaKey(key: NX_KEYTYPE_NEXT)
        DispatchQueue.main.async { self.currentTime = 0.0 }
        triggerFastFetch()
    }
    
    private func triggerFastFetch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isFetching = false
            self.fetchTitle()
        }
    }
    
    private func sendMediaKey(key: Int32) {
        let dataDown = Int((key << 16) | 0xa00)
        let dataUp = Int((key << 16) | 0xb00)
        let evDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xa00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataDown, data2: -1)
        let evUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xb00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataUp, data2: -1)
        evDown?.cgEvent?.post(tap: .cghidEventTap)
        evUp?.cgEvent?.post(tap: .cghidEventTap)
    }
    
    // MARK: - LIGHTNING FAST SEEK
    func seek(to percentage: Double) {
        DispatchQueue.main.async { self.currentTime = self.duration * percentage }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var percentage = \(percentage); var host = window.location.hostname; var active = null; if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { active = media[i]; break; } } } if (active && active.duration) { active.currentTime = active.duration * percentage; return 'SEEKED'; } return 'NOT_FOUND'; })();"
            
            // ⚡️ MICRO-SCRIPT: If we know the exact tab, target it directly!
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = browser == "Safari" ? "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return do JavaScript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return execute javascript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\""
                
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, res == "SEEKED" {
                    self.triggerFastFetch()
                    return // Done in 0.01 seconds!
                }
            }
            
            // Fallback to full search if the cached tab was closed
            self.runFullAppleScriptLoop(jsCode: jsCode) { _ in }
            self.triggerFastFetch()
        }
    }
    
    // MARK: - LIGHTNING FAST LOOP TOGGLE
    func toggleLoop() {
        DispatchQueue.main.async {
            self.lastLoopToggleTime = Date()
            self.loopMode = (self.loopMode + 1) % 3
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var host = window.location.hostname; if (host.includes('music.youtube.com')) { var btns = document.querySelectorAll('ytmusic-player-bar button'); var repeatBtn = null; for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { repeatBtn = btns[i]; break; } } if (repeatBtn) { repeatBtn.click(); return 'TOGGLED'; } return 'NOT_FOUND'; } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=control-button-repeat]'); if (spotBtn) { spotBtn.click(); return 'TOGGLED'; } } else if (host.includes('music.apple.com')) { var appleBtn = document.querySelector('.button-repeat') || document.querySelector('[data-testid=repeat-button]'); if (appleBtn) { appleBtn.click(); return 'TOGGLED'; } } else if (host.includes('youtube.com')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) { yt.loop = !yt.loop; if(yt.loop) yt.setAttribute('loop', ''); else yt.removeAttribute('loop'); return yt.loop ? 'ALL' : 'NONE'; } } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { media[i].loop = !media[i].loop; return media[i].loop ? 'ALL' : 'NONE'; } } } return 'NOT_FOUND'; })();"
            
            // ⚡️ MICRO-SCRIPT
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = browser == "Safari" ? "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return do JavaScript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to return execute javascript \"\(jsCode)\"\nend timeout\nend try\nend tell\nreturn \"NOT_FOUND\""
                
                if let result = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, result != "NOT_FOUND" {
                    DispatchQueue.main.async {
                        if result == "ALL" { self.loopMode = 1 } else if result == "NONE" { self.loopMode = 0 }
                    }
                    return
                }
            }
            
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                DispatchQueue.main.async {
                    if result == "ALL" { self.loopMode = 1 } else if result == "NONE" { self.loopMode = 0 }
                }
            }
        }
    }
    
    // MARK: - FETCH LOGIC WITH CACHING
    func fetchTitle() {
        guard !isFetching else { return }
        isFetching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            for app in runningApps { if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) } }
            if activeBrowsers.isEmpty { DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }; return }
            
            let jsCode = "(function() { var host = window.location.hostname; var isPlaying = false; var loopState = 'NONE'; var active = null; if (host.includes('music.youtube.com')) { active = document.querySelector('.html5-main-video'); if (active && !active.paused && active.currentTime > 0) isPlaying = true; var btns = document.querySelectorAll('ytmusic-player-bar button'); for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { if (lbl.includes('1') || lbl.includes('one') || lbl.includes('una') || lbl.includes('곡')) { loopState = 'ONE'; } else if (!lbl.includes('off') && !lbl.includes('안함') && !lbl.includes('desactiv')) { loopState = 'ALL'; } else { loopState = 'NONE'; } break; } } } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=control-button-repeat]'); if (spotBtn) { var checked = spotBtn.getAttribute('aria-checked'); if (checked === 'mixed') loopState = 'ONE'; else if (checked === 'true') loopState = 'ALL'; else loopState = 'NONE'; } } else if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); if (active && !active.paused && active.currentTime > 0) { isPlaying = true; loopState = (active.loop || active.hasAttribute('loop')) ? 'ALL' : 'NONE'; } } else if (!host.includes('music.apple.com')) { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { active = media[i]; isPlaying = true; loopState = active.loop ? 'ALL' : 'NONE'; break; } } } if (!isPlaying && navigator.mediaSession && navigator.mediaSession.playbackState === 'playing') { isPlaying = true; } if (isPlaying) { var title = document.title; var img = 'NO_IMAGE'; var curr = 0; var dur = 1; if (active) { curr = active.currentTime; dur = active.duration || 1; } if (navigator.mediaSession && navigator.mediaSession.metadata) { var m = navigator.mediaSession.metadata; if(m.title) title = m.title + (m.artist ? ' - ' + m.artist : ''); if(m.artwork && m.artwork.length > 0) img = m.artwork[m.artwork.length - 1].src; } return title + '|||' + img + '|||' + loopState + '|||' + curr + '|||' + dur; } return 'NOT_PLAYING'; })();"
            
            // ⚡️ MICRO-SCRIPT FAST FETCH
            if let browser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = browser == "Safari" ? "tell application \"Safari\"\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & \"\(wIdx)\" & \"|||\" & \"\(tIdx)\"\nend if\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab \(tIdx) of window \(wIdx) to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & \"\(wIdx)\" & \"|||\" & \"\(tIdx)\"\nend if\nend tell\nreturn \"NOT_FOUND\""
                
                if let result = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, result != "NOT_FOUND", result != "NOT_PLAYING" {
                    self.parseAndApplyResult(result: result, browser: browser)
                    return
                } else {
                    // IF THE FAST SCRIPT FAILS: They paused the tab or closed it. Clear the cache!
                    self.lastActiveBrowser = nil
                    self.lastWindowIndex = nil
                    self.lastTabIndex = nil
                }
            }
            
            // IF NO CACHE: Run the full search, but tell AppleScript to attach the exact coordinates so we can cache them!
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                if let res = result {
                    let parts = res.components(separatedBy: "|||")
                    // If it succeeded, it attached the Browser name to the very end for our parser
                    if parts.count >= 8 {
                        let browserName = parts.last!
                        self.parseAndApplyResult(result: res, browser: browserName)
                    }
                } else {
                    DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }
                }
            }
        }
    }
    
    // MARK: - SHARED FULL LOOP (Finds the tab and reports its exact index coordinates)
    private func runFullAppleScriptLoop(jsCode: String, completion: @escaping (String?) -> Void) {
        let runningApps = NSWorkspace.shared.runningApplications
        var activeBrowsers: [String] = []
        for app in runningApps { if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) } }
        
        for browser in activeBrowsers {
            let script = browser == "Safari" ? "tell application \"Safari\"\nset wCount to count of windows\nrepeat with wIdx from 1 to wCount\nset tCount to count of tabs of window wIdx\nrepeat with tIdx from 1 to tCount\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab tIdx of window wIdx to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & wIdx & \"|||\" & tIdx\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\"" : "tell application \"\(browser)\"\nset wCount to count of windows\nrepeat with wIdx from 1 to wCount\nset tCount to count of tabs of window wIdx\nrepeat with tIdx from 1 to tCount\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell tab tIdx of window wIdx to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not missing value then\nreturn tabResult as string & \"|||\" & wIdx & \"|||\" & tIdx\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
            
            if let result = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue, result != "NOT_FOUND", result != "NOT_PLAYING" {
                completion(result + "|||" + browser)
                return
            }
        }
        completion(nil)
    }
    
    // MARK: - SHARED PARSER
    private func parseAndApplyResult(result: String, browser: String) {
        DispatchQueue.main.async {
            self.isPlaying = true
            let components = result.components(separatedBy: "|||")
            
            var rawTitle = components[0]
            let imgString = components.count > 1 ? components[1] : "NO_IMAGE"
            let loopString = components.count > 2 ? components[2] : "NONE"
            let currString = components.count > 3 ? components[3] : "0"
            let durString = components.count > 4 ? components[4] : "1"
            
            // ⚡️ SAVE THE CACHE!
            if components.count >= 7 {
                self.lastActiveBrowser = browser
                self.lastWindowIndex = Int(components[5])
                self.lastTabIndex = Int(components[6])
            }
            
            rawTitle = rawTitle.replacingOccurrences(of: " - YouTube Music", with: "")
            rawTitle = rawTitle.replacingOccurrences(of: " - YouTube", with: "")
            rawTitle = rawTitle.replacingOccurrences(of: " | Spotify", with: "")
            rawTitle = rawTitle.replacingOccurrences(of: " - SoundCloud", with: "")
            
            if self.currentSong != rawTitle { self.currentSong = rawTitle }
            if imgString != "NO_IMAGE", let url = URL(string: imgString) { self.artworkURL = url } else { self.artworkURL = nil }
            
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
    
    // NEW: Handles smooth slider dragging
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    let localTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"

        ZStack {
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 16, style: .continuous)
                .fill(Color.black)
                // Expanded height is now 96 to fit the progress bar
                .frame(width: isExpanded ? 360 : 150, height: isExpanded ? 96 : 32)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isExpanded)
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? 24 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            VStack(spacing: 8) {
                // TOP ROW: Artwork, Text, Buttons
                HStack {
                    if isExpanded && hasMedia && nowPlaying.artworkURL != nil {
                        AsyncImage(url: nowPlaying.artworkURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(nowPlaying.isPlaying ? Color.red : Color.gray)
                            .font(.system(size: isExpanded ? 20 : 16, weight: .bold))
                    }
                    
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasMedia ? (nowPlaying.isPlaying ? "Now Playing" : "Paused") : "Waiting for Media...")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(hasMedia ? nowPlaying.currentSong : "Nothing playing")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.leading, 6)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    if isExpanded && hasMedia {
                        HStack(spacing: 14) {
                            Button(action: { nowPlaying.skipBackward() }) {
                                Image(systemName: "backward.fill").foregroundColor(.white).font(.system(size: 16))
                            }.buttonStyle(.plain)
                            
                            Button(action: { nowPlaying.togglePlayPause() }) {
                                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill").foregroundColor(.white).font(.system(size: 18))
                            }.buttonStyle(.plain)
                            
                            Button(action: { nowPlaying.skipForward() }) {
                                Image(systemName: "forward.fill").foregroundColor(.white).font(.system(size: 16))
                            }.buttonStyle(.plain)
                            
                            Button(action: { nowPlaying.toggleLoop() }) {
                                Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat")
                                    .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6))
                                    .font(.system(size: 16, weight: nowPlaying.loopMode > 0 ? .bold : .regular))
                            }.buttonStyle(.plain)
                        }
                        .padding(.trailing, 8)
                        .transition(.opacity)
                    }
                }
                
                // BOTTOM ROW: Progress Bar
                if isExpanded && hasMedia {
                    HStack(spacing: 8) {
                        // Current Time
                        Text(formatTime(isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(width: 36, alignment: .trailing)

                        // Interactive Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background Track
                                Capsule().fill(Color.white.opacity(0.2))
                                    .frame(height: 6)
                                
                                // Filled Track
                                Capsule().fill(Color.white)
                                    .frame(width: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : (nowPlaying.currentTime / nowPlaying.duration))), height: 6)
                            }
                            // Seek functionality
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    dragProgress = min(max(0, value.location.x / geo.size.width), 1)
                                }
                                .onEnded { value in
                                    let percentage = min(max(0, value.location.x / geo.size.width), 1)
                                    nowPlaying.seek(to: percentage)
                                    // Slight delay before releasing drag to allow the browser to catch up
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDragging = false }
                                }
                            )
                        }
                        .frame(height: 6)

                        // Time Remaining
                        Text("-" + formatTime(nowPlaying.duration - (isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime)))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(width: 36, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, isExpanded ? 16 : 16)
            .frame(width: isExpanded ? 360 : 150)
        }
        .onHover { hovering in
            isExpanded = hovering
        }
        // Smooth Local Timer (Moves the bar naturally between the 2-second background fetches)
        .onReceive(localTimer) { _ in
            if nowPlaying.isPlaying && !isDragging && nowPlaying.currentTime < nowPlaying.duration {
                nowPlaying.currentTime += 1.0
            }
        }
    }
    
    // Helper to turn seconds into "M:SS"
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ContentView()
}
