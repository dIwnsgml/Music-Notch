import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    @Published var artworkURL: URL? = nil
    @Published var isPlaying: Bool = false
    @Published var isLooping: Bool = false
    
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
    
    // MARK: - STRICT LOOP TOGGLE
    func toggleLoop() {
        DispatchQueue.global(qos: .userInitiated).async {
            // FIXED JS: Only targets tabs where the video is actively playing right now
            let jsCode = "(function() { var active = null; if (window.location.hostname.includes('youtube')) { var yt = document.querySelector('.html5-main-video'); if (yt && !yt.paused && yt.currentTime > 0) active = yt; } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { active = media[i]; break; } } } if (active) { var isCurrentlyLooping = active.loop || active.hasAttribute('loop'); var newState = !isCurrentlyLooping; active.loop = newState; if (newState) { active.setAttribute('loop', ''); } else { active.removeAttribute('loop'); } return newState ? 'TRUE' : 'FALSE'; } return 'NOT_FOUND'; })();"
            
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            for app in runningApps {
                if let name = app.localizedName, self.supportedBrowsers.contains(name) { activeBrowsers.append(name) }
            }
            
            for browser in activeBrowsers {
                let script: String
                if browser == "Safari" {
                    script = "tell application \"Safari\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset tabResult to \"NOT_FOUND\"\ntry\nwith timeout of 1 second\ntell t to set tabResult to do JavaScript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is \"TRUE\" or tabResult is \"FALSE\" then\nreturn tabResult as string\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
                } else {
                    script = "tell application \"\(browser)\"\nrepeat with w in windows\nrepeat with t in tabs of w\nset tabResult to \"NOT_FOUND\"\ntry\nwith timeout of 1 second\ntell t to set tabResult to execute javascript \"\(jsCode)\"\nend timeout\nend try\nif tabResult is \"TRUE\" or tabResult is \"FALSE\" then\nreturn tabResult as string\nend if\nend repeat\nend repeat\nend tell\nreturn \"NOT_FOUND\""
                }
                
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    let output = appleScript.executeAndReturnError(&error)
                    if let result = output.stringValue, result == "TRUE" || result == "FALSE" {
                        DispatchQueue.main.async {
                            self.lastLoopToggleTime = Date()
                            self.isLooping = (result == "TRUE")
                        }
                        return
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
            
            // FIXED JS: Returns NOT_PLAYING for paused tabs so AppleScript immediately skips them
            let jsCode = "(function() { var isPlaying = false; var isLooping = false; var active = null; if (window.location.hostname.includes('youtube')) { active = document.querySelector('.html5-main-video'); if (active && !active.paused && active.currentTime > 0) isPlaying = true; } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (!media[i].paused && media[i].currentTime > 0) { active = media[i]; isPlaying = true; break; } } } if (!isPlaying && navigator.mediaSession && navigator.mediaSession.playbackState === 'playing') { var host = window.location.hostname; if (host.includes('spotify') || host.includes('soundcloud') || host.includes('music.apple')) { isPlaying = true; } } if (isPlaying) { if (active) { isLooping = active.loop || active.hasAttribute('loop'); } var title = document.title; var img = 'NO_IMAGE'; if (navigator.mediaSession && navigator.mediaSession.metadata) { var m = navigator.mediaSession.metadata; if(m.title) { title = m.title + (m.artist ? ' - ' + m.artist : ''); } if(m.artwork && m.artwork.length > 0) { img = m.artwork[m.artwork.length - 1].src; } } return title + '|||' + img + '|||' + (isLooping ? 'TRUE' : 'FALSE'); } return 'NOT_PLAYING'; })();"
            
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
                            let loopString = components.count > 2 ? components[2] : "FALSE"
                            
                            rawTitle = rawTitle.replacingOccurrences(of: " - YouTube Music", with: "")
                            rawTitle = rawTitle.replacingOccurrences(of: " - YouTube", with: "")
                            rawTitle = rawTitle.replacingOccurrences(of: " | Spotify", with: "")
                            rawTitle = rawTitle.replacingOccurrences(of: " - SoundCloud", with: "")
                            
                            if self.currentSong != rawTitle { self.currentSong = rawTitle }
                            if imgString != "NO_IMAGE", let url = URL(string: imgString) { self.artworkURL = url } else { self.artworkURL = nil }
                            
                            if Date().timeIntervalSince(self.lastLoopToggleTime) > 3.0 {
                                self.isLooping = (loopString == "TRUE")
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
                // Expanded width to 360 to fit the new Loop button
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
                        
                        // NEW: THE LOOP BUTTON
                        Button(action: { nowPlaying.toggleLoop() }) {
                            Image(systemName: "repeat")
                                // Turns neon green when active, just like iOS
                                .foregroundColor(nowPlaying.isLooping ? .green : .white.opacity(0.6))
                                .font(.system(size: 16, weight: nowPlaying.isLooping ? .bold : .regular))
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
