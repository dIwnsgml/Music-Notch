import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    @Published var artworkURL: URL? = nil
    @Published var isPlaying: Bool = false
    
    // NEW: 3-State Loop Mode (0: Off, 1: Loop All, 2: Loop One)
    @Published var loopMode: Int = 0
    
    var timer: Timer?
    private var isFetching = false
    private var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    
    let supportedBrowsers = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Safari"]
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
    }
    
    // MARK: - MEDIA CONTROLS
    let NX_KEYTYPE_PLAY: Int32 = 16
    let NX_KEYTYPE_NEXT: Int32 = 17
    let NX_KEYTYPE_PREVIOUS: Int32 = 18
    
    func skipBackward() { sendMediaKey(key: NX_KEYTYPE_PREVIOUS) }
    func togglePlayPause() { sendMediaKey(key: NX_KEYTYPE_PLAY) }
    func skipForward() { sendMediaKey(key: NX_KEYTYPE_NEXT) }
    
    private func sendMediaKey(key: Int32) {
        let dataDown = Int((key << 16) | 0xa00)
        let dataUp = Int((key << 16) | 0xb00)
        
        let evDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xa00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataDown, data2: -1)
        let evUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xb00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataUp, data2: -1)
        
        evDown?.cgEvent?.post(tap: .cghidEventTap)
        evUp?.cgEvent?.post(tap: .cghidEventTap)
    }
    
    // MARK: - 3-STATE LOOP TOGGLE
    func toggleLoop() {
        DispatchQueue.global(qos: .userInitiated).async {
            // JS: Finds the UI button and clicks it. Supports YT Music, Spotify, Apple Music.
            let jsCode = "(function() { var host = window.location.hostname; if (host.includes('music.youtube.com')) { var btns = document.querySelectorAll('ytmusic-player-bar button'); var repeatBtn = null; for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { repeatBtn = btns[i]; break; } } if (repeatBtn) { repeatBtn.click(); return 'TOGGLED'; } return 'NOT_FOUND'; } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=control-button-repeat]'); if (spotBtn) { spotBtn.click(); return 'TOGGLED'; } } else if (host.includes('music.apple.com')) { var appleBtn = document.querySelector('.button-repeat') || document.querySelector('[data-testid=repeat-button]'); if (appleBtn) { appleBtn.click(); return 'TOGGLED'; } } else if (host.includes('youtube.com')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) { yt.loop = !yt.loop; if(yt.loop) yt.setAttribute('loop', ''); else yt.removeAttribute('loop'); return yt.loop ? 'ALL' : 'NONE'; } } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { media[i].loop = !media[i].loop; return media[i].loop ? 'ALL' : 'NONE'; } } } return 'NOT_FOUND'; })();"
            
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            for app in runningApps {
                if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) }
            }
            
            for browser in activeBrowsers {
                let script: String
                if browser == "Safari" {
                    script = "tell application \"Safari\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset tabResult to \"NOT_FOUND\"\ntry\nwith timeout of 1 second\ntell t to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is \"ALL\" or tabResult is \"NONE\" or tabResult is \"TOGGLED\" then\nreturn tabResult as string\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
                } else {
                    script = "tell application \"\(browser)\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset tabResult to \"NOT_FOUND\"\ntry\nwith timeout of 1 second\ntell t to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is \"ALL\" or tabResult is \"NONE\" or tabResult is \"TOGGLED\" then\nreturn tabResult as string\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
                }
                
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    let output = appleScript.executeAndReturnError(&error)
                    if let result = output.stringValue {
                        DispatchQueue.main.async {
                            self.lastLoopToggleTime = Date()
                            // Cycle through the 3 states locally for instant visual feedback
                            if result == "TOGGLED" { self.loopMode = (self.loopMode + 1) % 3 }
                            else if result == "ALL" { self.loopMode = 1 }
                            else if result == "NONE" { self.loopMode = 0 }
                        }
                        if result != "NOT_FOUND" { return }
                    }
                }
            }
        }
    }
    
    // MARK: - FETCH LOGIC
    func fetchTitle() {
        guard !isFetching else { return }
        isFetching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            
            for app in runningApps {
                if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) }
            }
            
            if activeBrowsers.isEmpty {
                DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }
                return
            }
            
            // JS: Understands 'Off', 'All', and 'One' states based on labels or SVG states.
            let jsCode = "(function() { var host = window.location.hostname; var isPlaying = false; var loopState = 'NONE'; if (host.includes('music.youtube.com')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) isPlaying = true; var btns = document.querySelectorAll('ytmusic-player-bar button'); for(var i=0; i<btns.length; i++) { var lbl = (btns[i].getAttribute('aria-label') || '').toLowerCase(); var html = btns[i].innerHTML; if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) { if (lbl.includes('1') || lbl.includes('one') || lbl.includes('una') || lbl.includes('곡')) { loopState = 'ONE'; } else if (!lbl.includes('off') && !lbl.includes('안함') && !lbl.includes('desactiv')) { loopState = 'ALL'; } else { loopState = 'NONE'; } break; } } } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=control-button-repeat]'); if (spotBtn) { var checked = spotBtn.getAttribute('aria-checked'); if (checked === 'mixed') loopState = 'ONE'; else if (checked === 'true') loopState = 'ALL'; else loopState = 'NONE'; } } else if (host.includes('youtube.com')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) { isPlaying = true; loopState = (yt.loop || yt.hasAttribute('loop')) ? 'ALL' : 'NONE'; } } else if (!host.includes('music.apple.com')) { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { isPlaying = true; loopState = media[i].loop ? 'ALL' : 'NONE'; break; } } } if (!isPlaying && navigator.mediaSession && navigator.mediaSession.playbackState === 'playing') { isPlaying = true; } if (isPlaying) { var title = document.title; var img = 'NO_IMAGE'; if (navigator.mediaSession && navigator.mediaSession.metadata) { var m = navigator.mediaSession.metadata; if(m.title) title = m.title + (m.artist ? ' - ' + m.artist : ''); if(m.artwork && m.artwork.length > 0) img = m.artwork[m.artwork.length - 1].src; } return title + '|||' + img + '|||' + loopState; } return 'NOT_PLAYING'; })();"
            
            for browser in activeBrowsers {
                let script: String
                if browser == "Safari" {
                    script = "tell application \"Safari\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell t to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not \"missing value\" and tabResult is not missing value then\nreturn tabResult as string\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
                } else {
                    script = "tell application \"\(browser)\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset tabResult to \"NOT_PLAYING\"\ntry\nwith timeout of 1 second\ntell t to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is not \"NOT_PLAYING\" and tabResult is not \"\" and tabResult is not \"missing value\" and tabResult is not missing value then\nreturn tabResult as string\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
                }
                
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    let output = appleScript.executeAndReturnError(&error)
                    
                    if let result = output.stringValue, result != "NOT_FOUND", result != "NOT_PLAYING", !result.isEmpty {
                        DispatchQueue.main.async {
                            self.isPlaying = true
                            let components = result.components(separatedBy: "|||")
                            var rawTitle = components[0]
                            let imgString = components.count > 1 ? components[1] : "NO_IMAGE"
                            let loopString = components.count > 2 ? components[2] : "NONE"
                            
                            rawTitle = rawTitle.replacingOccurrences(of: " - YouTube Music", with: "")
                            rawTitle = rawTitle.replacingOccurrences(of: " - YouTube", with: "")
                            rawTitle = rawTitle.replacingOccurrences(of: " | Spotify", with: "")
                            rawTitle = rawTitle.replacingOccurrences(of: " - SoundCloud", with: "")
                            
                            if self.currentSong != rawTitle { self.currentSong = rawTitle }
                            if imgString != "NO_IMAGE", let url = URL(string: imgString) { self.artworkURL = url } else { self.artworkURL = nil }
                            
                            // Apply the parsed loop state (0, 1, or 2)
                            if Date().timeIntervalSince(self.lastLoopToggleTime) > 3.0 {
                                if loopString == "ALL" { self.loopMode = 1 }
                                else if loopString == "ONE" { self.loopMode = 2 }
                                else { self.loopMode = 0 } // Fixes the "bleed" issue!
                            }
                            self.isFetching = false
                        }
                        return
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isPlaying = false
                self.isFetching = false
            }
        }
    }
}

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"

        ZStack {
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 16, style: .continuous)
                .fill(Color.black)
                .frame(width: isExpanded ? 360 : 150, height: isExpanded ? 70 : 32)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isExpanded)
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? 24 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            HStack {
                // ARTWORK
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
                
                // TEXT
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
                
                // INTERACTIVE MEDIA CONTROLS
                if isExpanded && hasMedia {
                    HStack(spacing: 14) {
                        Button(action: { nowPlaying.skipBackward() }) {
                            Image(systemName: "backward.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { nowPlaying.togglePlayPause() }) {
                            Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { nowPlaying.skipForward() }) {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        
                        // 3-STATE LOOP BUTTON
                        Button(action: { nowPlaying.toggleLoop() }) {
                            // Switches to the "repeat.1" icon when loopMode is 2
                            Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat")
                                // Colors green if mode is 1 or 2
                                .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6))
                                .font(.system(size: 16, weight: nowPlaying.loopMode > 0 ? .bold : .regular))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 8)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, isExpanded ? 16 : 16)
            .frame(width: isExpanded ? 360 : 150)
        }
        .onHover { hovering in
            isExpanded = hovering
        }
    }
}
#Preview {
    ContentView()
}
