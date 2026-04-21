import Foundation
import AppKit

extension NowPlayingManager {
    
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
            
            if let rawBrowser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "")
                let fastScript = self.buildAppleScript(browser: cleanBrowser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                _ = NSAppleScript(source: fastScript)?.executeAndReturnError(nil)
            }
            self.triggerFastFetch()
        }
    }
    
    func skipBackward() {
        let rawBrowser = self.lastActiveBrowser ?? ""
        let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "")
        
        if cleanBrowser == "SpotifyNative" || cleanBrowser == "Spotify" {
            DispatchQueue.global(qos: .userInitiated).async {
                if self.currentTime > 3.0 { _ = NSAppleScript(source: "tell application \"Spotify\"\nset player position to 0\nplay\nend tell")?.executeAndReturnError(nil)
                } else { _ = NSAppleScript(source: "tell application \"Spotify\" to previous track")?.executeAndReturnError(nil) }
                DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch()
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var host = window.location.hostname; var active = null; if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (media[i].duration > 1) { active = media[i]; break; } } } if (active) { if (active.currentTime > 3 || active.ended || (active.duration > 0 && active.duration - active.currentTime < 1.5)) { active.currentTime = 0; active.play(); return 'RESTARTED'; } } return 'NOT_PLAYING'; })();"
            
            if let _ = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: cleanBrowser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, res == "RESTARTED" {
                    DispatchQueue.main.async { self.currentTime = 0.0; self.isPlaying = true; self.updateActiveLyric() }; self.triggerFastFetch(); return
                }
            }
            self.sendMediaKey(key: 18); DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch()
        }
    }
    
    func togglePlayPause() {
        DispatchQueue.main.async { self.lastControlAction = UUID() }
        
        let rawBrowser = self.lastActiveBrowser ?? ""
        let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "")
        
        if cleanBrowser == "SpotifyNative" || cleanBrowser == "Spotify" {
            DispatchQueue.global(qos: .userInitiated).async { _ = NSAppleScript(source: "tell application \"Spotify\" to playpause")?.executeAndReturnError(nil); DispatchQueue.main.async { self.isPlaying.toggle() }; self.triggerFastFetch() }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { var host = window.location.hostname; if (host.includes('music.youtube.com')) { var playBtn = document.querySelector('#play-pause-button'); if (playBtn) { playBtn.click(); return 'TOGGLED'; } } else if (host.includes('spotify.com')) { var spotBtn = document.querySelector('[data-testid=\"control-button-playpause\"]'); if (spotBtn) { spotBtn.click(); return 'TOGGLED'; } } var active = null; if (host.includes('youtube.com')) { active = document.querySelector('.html5-main-video'); } else { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (media[i].duration > 1) { active = media[i]; break; } } if(!active && media.length > 0) active = media[0]; } if (active) { if (active.paused || active.ended) { active.play(); return 'PLAYED'; } else { active.pause(); return 'PAUSED'; } } return 'NOT_PLAYING'; })();"
            
            if let _ = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: cleanBrowser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, (res == "PLAYED" || res == "PAUSED" || res == "TOGGLED") {
                    DispatchQueue.main.async { if res == "TOGGLED" { self.isPlaying.toggle() } else { self.isPlaying = (res == "PLAYED") } }
                    self.triggerFastFetch(); return
                }
            }
            
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                if let res = result {
                    let action = res.components(separatedBy: "|||").first ?? ""
                    if action == "PLAYED" || action == "PAUSED" || action == "TOGGLED" {
                        DispatchQueue.main.async { if action == "TOGGLED" { self.isPlaying.toggle() } else { self.isPlaying = (action == "PLAYED") } }
                        self.triggerFastFetch()
                        return
                    }
                }
                self.sendMediaKey(key: 16); DispatchQueue.main.async { self.isPlaying.toggle() }; self.triggerFastFetch()
            }
        }
    }
    
    func skipForward() {
        let rawBrowser = self.lastActiveBrowser ?? ""
        let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "")
        
        if cleanBrowser == "SpotifyNative" || cleanBrowser == "Spotify" {
            DispatchQueue.global(qos: .userInitiated).async { _ = NSAppleScript(source: "tell application \"Spotify\" to next track")?.executeAndReturnError(nil); DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch() }
            return
        }
        sendMediaKey(key: 17); DispatchQueue.main.async { self.currentTime = 0.0 }; self.triggerFastFetch()
    }
    
    func seek(to percentage: Double) {
        DispatchQueue.main.async {
            self.currentTime = self.duration * percentage
            self.isPlaying = true
            self.updateActiveLyric()
        }
        
        let rawBrowser = self.lastActiveBrowser ?? ""
        let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "")
        
        if cleanBrowser == "SpotifyNative" || cleanBrowser == "Spotify" {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Spotify\"\nset dur to (duration of current track) / 1000\nset player position to dur * \(percentage)\nplay\nend tell"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
                self.triggerFastFetch()
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = "(function() { function pt(str) { if(!str) return 0; var p = str.split(':'); var s = 0; var m = 1; while (p.length > 0) { s += m * parseInt(p.pop(), 10); m *= 60; } return s; } var percentage = \(percentage); var host = window.location.hostname; var active = null; if (host.includes('music.youtube.com')) { active = document.querySelector('.html5-main-video'); var ytmTime = document.querySelector('.time-info.ytmusic-player-bar'); if (active && ytmTime) { var p = ytmTime.innerText.split('/'); if (p.length === 2) { var localCurr = pt(p[0].trim()); var localDur = pt(p[1].trim()); if (localDur > 0) { var offset = active.currentTime - localCurr; active.currentTime = offset + (localDur * percentage); if(active.paused || active.ended) active.play(); return 'SEEKED'; } } } } if (host.includes('youtube.com') && !host.includes('music.youtube.com')) { active = document.querySelector('.html5-main-video'); } else if (!host.includes('music.youtube.com')) { var media = document.querySelectorAll('video, audio'); for(var i=0; i<media.length; i++) { if (media[i].duration > 1) { active = media[i]; break; } } } if (active && active.duration) { active.currentTime = active.duration * percentage; if(active.paused || active.ended) active.play(); return 'SEEKED'; } return 'NOT_PLAYING'; })();"
            
            if let _ = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: cleanBrowser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                if let res = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue, res == "SEEKED" { self.triggerFastFetch(); return }
            }
            if let script = NSAppleScript(source: self.buildAppleScript(browser: "Safari", jsCode: jsCode)) { _ = script.executeAndReturnError(nil) }
            self.triggerFastFetch()
        }
    }
    
    func toggleLoop() {
        let rawBrowser = self.lastActiveBrowser ?? ""
        let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "")
        let isTwoState = rawBrowser.hasSuffix("_YT") || cleanBrowser == "SpotifyNative" || cleanBrowser == "Spotify"
        
        // ⚡️ THE FIX: We calculate the next mode cleanly in Swift...
        let nextMode = isTwoState ? (self.loopMode == 0 ? 1 : 0) : ((self.loopMode + 1) % 3)
        
        DispatchQueue.main.async {
            self.lastLoopToggleTime = Date()
            self.loopMode = nextMode
        }
        
        if cleanBrowser == "Music" || cleanBrowser == "AppleMusicNative" {
            DispatchQueue.global(qos: .userInitiated).async {
                // ⚡️ ...And explicitly force Apple Music to adopt that exact state!
                // No more AppleScript 'if/else' confusion!
                let command = nextMode == 1 ? "all" : (nextMode == 2 ? "one" : "off")
                let script = "tell application \"Music\" to set song repeat to \(command)"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
                self.triggerFastFetch()
            }
            return
        }
        
        if cleanBrowser == "SpotifyNative" || cleanBrowser == "Spotify" {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Spotify\"\nset repeating to not repeating\nend tell"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
                self.triggerFastFetch()
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let jsCode = """
                (function() {
                    var host = window.location.hostname;
                    if (host.includes('music.youtube.com')) {
                        var btns = document.querySelectorAll('ytmusic-player-bar button, ytmusic-player-bar tp-yt-paper-icon-button');
                        var repeatBtn = null;
                        for(var i=0; i<btns.length; i++) {
                            var lbl = (btns[i].getAttribute('aria-label') || btns[i].getAttribute('title') || '').toLowerCase();
                            var html = btns[i].innerHTML;
                            if(html.includes('17.293') || html.includes('21 10a1') || html.includes('M7 7h10') || lbl.includes('repeat') || lbl.includes('반복')) {
                                repeatBtn = btns[i]; break;
                            }
                        }
                        if (repeatBtn) { repeatBtn.click(); return 'TOGGLED'; }
                    } else if (host.includes('spotify.com')) {
                        var spotBtn = document.querySelector('[data-testid="control-button-repeat"]');
                        if (spotBtn) { spotBtn.click(); return 'TOGGLED'; }
                    } else if (host.includes('music.apple.com')) {
                        var appleBtn = document.querySelector('.button-repeat') || document.querySelector('[data-testid="repeat-button"]');
                        if (appleBtn) { appleBtn.click(); return 'TOGGLED'; }
                    } else if (host.includes('youtube.com')) {
                        var yt = document.querySelector('.html5-main-video');
                        if (yt && !yt.paused && yt.currentTime > 0) {
                            yt.loop = !yt.loop;
                            if(yt.loop) yt.setAttribute('loop', ''); else yt.removeAttribute('loop');
                            return yt.loop ? 'ALL' : 'NONE';
                        }
                    }
                    return 'NOT_PLAYING';
                })();
                """
            
            if let _ = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let fastScript = self.buildAppleScript(browser: cleanBrowser, jsCode: jsCode, wIdx: wIdx, tIdx: tIdx)
                _ = NSAppleScript(source: fastScript)?.executeAndReturnError(nil)
            } else if let script = NSAppleScript(source: self.buildAppleScript(browser: "Safari", jsCode: jsCode)) {
                _ = script.executeAndReturnError(nil)
            }
            self.triggerFastFetch()
        }
    }
    
    func triggerFastFetch() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.isFetching = false; self.fetchTitle() } }
    
    func sendMediaKey(key: Int32) {
        let dataDown = Int((key << 16) | 0xa00); let dataUp = Int((key << 16) | 0xb00)
        let evDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xa00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataDown, data2: -1)
        let evUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: .init(rawValue: 0xb00), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: dataUp, data2: -1)
        evDown?.cgEvent?.post(tap: .cghidEventTap); evUp?.cgEvent?.post(tap: .cghidEventTap)
    }
    
    // ---------------------------------------------------------
    // 🟢 SPOTIFY NATIVE CONTROLS
    // ---------------------------------------------------------
    
    // Toggles Spotify Shuffle
    func toggleSpotifyShuffle() {
        let script = """
        tell application "Spotify"
            if shuffling then
                set shuffling to false
            else
                set shuffling to true
            end if
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
            // Trigger a UI refresh shortly after so the buttons update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.fetchTitle() }
        }
    }
    
    // Toggles Spotify Loop
    func toggleSpotifyRepeat() {
        let script = """
        tell application "Spotify"
            if repeating then
                set repeating to false
            else
                set repeating to true
            end if
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.fetchTitle() }
        }
    }
    
    // Play a specific URI (Great for building a quick "Playlists" menu)
    func playSpotifyURI(_ uri: String) {
        let script = "tell application \"Spotify\" to play track \"\(uri)\""
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
    }
}
