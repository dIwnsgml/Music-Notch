import Foundation
import AppKit
import SwiftUI

extension NowPlayingManager {
    
    func fetchTitle() {
        if isFetching { if Date().timeIntervalSince(lastFetchTime) > 3.0 { isFetching = false } else { return } }
        isFetching = true
        lastFetchTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let runningApps = NSWorkspace.shared.runningApplications
            var activeBrowsers: [String] = []
            var isSpotifyNativeRunning = false
            var isAppleMusicRunning = false
            
            for app in runningApps {
                if let name = app.localizedName {
                    // ⚡️ FIX: Only scan browsers that the user has explicitly allowed
                    if self.allowedBrowsers.contains(name) { activeBrowsers.append(name) }
                    // ⚡️ FIX: Only scan Spotify if the user has enabled it
                    if name == "Spotify" && self.enableSpotify { isSpotifyNativeRunning = true }
                    
                    if name == "Music" && self.enableAppleMusic { isAppleMusicRunning = true }
                }
            }
            
            // ⚡️ NEW: Apple Music Integration
            if isAppleMusicRunning {
                let musicScript = """
                tell application "Music"
                    if player state is playing then
                        set tName to name of current track
                        set tArtist to artist of current track
                        set tPos to player position
                        set tDur to duration of current track
                        try
                            set rep to song repeat
                            if rep is one then
                                set loopState to "ONE"
                            else if rep is all then
                                set loopState to "ALL"
                            else
                                set loopState to "NONE"
                            end if
                        on error
                            set loopState to "NONE"
                        end try
                        return tName & "|||" & tArtist & "|||APPLE_MUSIC_ART|||" & loopState & "|||" & tPos & "|||" & tDur
                    end if
                end tell
                return "NOT_PLAYING"
                """
                if let res = NSAppleScript(source: musicScript)?.executeAndReturnError(nil).stringValue, res != "NOT_PLAYING", res != "NOT_FOUND" {
                    self.parseAndApplyResult(result: res + "|||Queue unavailable for Apple Music", browser: "AppleMusicNative")
                    return
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
            
            let jsCode = "(function(){function pt(str){if(!str)return 0;var p=str.split(':');var s=0,m=1;while(p.length>0){s+=m*parseInt(p.pop(),10);m*=60;}return s;}var host=window.location.hostname;var active=null;var cTitle='',cArtist='',cImg='NO_IMAGE',cCurr=-1,cDur=-1,loopState='NONE',playlist='';if(host.includes('music.youtube.com')){active=document.querySelector('.html5-main-video');var tEl=document.querySelector('ytmusic-player-bar .title');var aEl=document.querySelector('ytmusic-player-bar .byline');if(tEl)cTitle=tEl.innerText;if(aEl)cArtist=aEl.innerText.split('•')[0].trim();var time=document.querySelector('.time-info.ytmusic-player-bar');if(time){var p=time.innerText.split('/');if(p.length===2){cCurr=pt(p[0]);cDur=pt(p[1]);}}try{var qItems=document.querySelectorAll('ytmusic-player-queue-item');var pArr=[];var start=0;for(var i=0;i<qItems.length;i++){if(qItems[i].hasAttribute('selected')||qItems[i].getAttribute('play-button-state')==='playing'){start=i;break;}}for(var j=start;j<qItems.length;j++){var tN=qItems[j].querySelector('.song-title, .title, yt-formatted-string[title]');var aN=qItems[j].querySelector('.byline');var iN=qItems[j].querySelector('img');var tText=tN?(tN.innerText||tN.getAttribute('title')||'').trim():'';var aText=aN?aN.innerText.replace(/\\n/g,'').trim():'Unknown';var iSrc=iN?(iN.src||''):'NO_IMAGE';if(tText){pArr.push(tText+'~~~'+aText+'~~~'+iSrc);}if(pArr.length>=15)break;}playlist=pArr.join('&&&');}catch(e){}}else if(host.includes('open.spotify.com')){active=document.querySelector('video, audio');var tEl=document.querySelector('[data-testid=context-item-info-title]');var aEl=document.querySelector('[data-testid=context-item-info-artist]');if(tEl)cTitle=tEl.innerText;if(aEl)cArtist=aEl.innerText;var cEl=document.querySelector('[data-testid=playback-position]');var dEl=document.querySelector('[data-testid=playback-duration]');if(cEl)cCurr=pt(cEl.innerText);if(dEl)cDur=pt(dEl.innerText);}else if(host.includes('youtube.com')){active=document.querySelector('.html5-main-video');loopState=(active&&(active.loop||active.hasAttribute('loop')))?'ALL':'NONE';if(active&&active.duration>0.05){cDur=active.duration-0.05;}var attrTitle=document.querySelector('.ytVideoAttributeViewModelTitle')||document.querySelector('#title h1 yt-formatted-string');var attrArtist=document.querySelector('.ytVideoAttributeViewModelSubtitle')||document.querySelector('#owner-name a');if(attrTitle)cTitle=attrTitle.innerText.trim();if(attrArtist)cArtist=attrArtist.innerText.trim();try{var ytdItems=document.querySelectorAll('ytd-playlist-panel-video-renderer');var ytdArr=[];var ytdStart=0;for(var k=0;k<ytdItems.length;k++){if(ytdItems[k].hasAttribute('selected')){ytdStart=k;break;}}for(var l=ytdStart;l<ytdItems.length;l++){var yT=ytdItems[l].querySelector('#video-title');var yA=ytdItems[l].querySelector('#byline');var yI=ytdItems[l].querySelector('img');var iSrc=yI?(yI.src||''):'NO_IMAGE';if(yT&&yT.innerText.trim()){ytdArr.push(yT.innerText.trim()+'~~~'+(yA?yA.innerText.trim():'Unknown')+'~~~'+iSrc);}if(ytdArr.length>=15)break;}playlist=ytdArr.join('&&&');}catch(e){}}else{var media=document.querySelectorAll('video, audio');for(var i=0;i<media.length;i++){if(!media[i].paused&&media[i].currentTime>0){active=media[i];break;}}if(!active && media.length > 0) active = media[0];}var isPlaying=(active&&!active.paused&&!active.ended&&active.currentTime>0);if(!isPlaying&&navigator.mediaSession&&navigator.mediaSession.playbackState==='playing')isPlaying=true;if(isPlaying){var title=cTitle||document.title;var artist=cArtist||'EMPTY_ARTIST';var curr=cCurr!==-1?cCurr:(active?active.currentTime:0);var dur=cDur!==-1&&isNaN(cDur)===false&&cDur!==0?cDur:(active?(active.duration||1):1);if(navigator.mediaSession&&navigator.mediaSession.metadata){var m=navigator.mediaSession.metadata;if(!cTitle&&m.title)title=m.title;if(artist==='EMPTY_ARTIST'&&m.artist)artist=m.artist;if(cImg==='NO_IMAGE'&&m.artwork&&m.artwork.length>0)cImg=m.artwork[m.artwork.length-1].src;}return title+'|||'+artist+'|||'+cImg+'|||'+loopState+'|||'+curr+'|||'+dur+'|||'+playlist;}return 'NOT_PLAYING';})();"
            
            self.runFullAppleScriptLoop(jsCode: jsCode) { result in
                if let res = result {
                    self.parseAndApplyResult(result: res, browser: res.components(separatedBy: "|||").last ?? "Unknown")
                } else {
                    DispatchQueue.main.async { self.isPlaying = false; self.isFetching = false }
                }
            }
        }
    }

    func runFullAppleScriptLoop(jsCode: String, completion: @escaping (String?) -> Void) {
        let runningApps = NSWorkspace.shared.runningApplications
        // ⚡️ FIX: Only loop through allowed browsers
        let browsers = runningApps.filter { self.allowedBrowsers.contains($0.localizedName ?? "") }
        
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
                
                if browser == "AppleMusicNative" {
                    self.fetchAppleMusicArtwork(title: rawTitle, artist: rawArtist)
                }
            }
            
            let displayString = rawArtist.isEmpty ? rawTitle : "\(rawTitle) - \(rawArtist)"
            if self.currentSong != displayString { self.currentSong = displayString }
            
            // ⚡️ FIX: Only update normal artwork if it's not Apple Music (because Apple Music fetches it asynchronously)
            if browser != "AppleMusicNative" {
                if imgString != "NO_IMAGE", let url = URL(string: imgString) {
                    if self.artworkURL != url { self.artworkURL = url; self.fetchDominantColor(from: url) }
                } else {
                    self.artworkURL = nil
                    self.artworkDominantColor = .green
                }
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
    
    // ⚡️ NEW: The iTunes API Fetcher for High-Res Apple Music Artwork
    func fetchAppleMusicArtwork(title: String, artist: String) {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artwork100 = first["artworkUrl100"] as? String else {
                return
            }
            
            // The API returns a 100x100 image by default.
            // We use this string replacement trick to force Apple's servers to give us a crisp 600x600 image!
            let highResUrlString = artwork100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            
            if let highResUrl = URL(string: highResUrlString) {
                DispatchQueue.main.async {
                    self.artworkURL = highResUrl
                    self.fetchDominantColor(from: highResUrl)
                }
            }
        }.resume()
    }
    
    func buildAppleScript(browser: String, jsCode: String, wIdx: Int? = nil, tIdx: Int? = nil) -> String {
        let escapedJS = jsCode.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        if let w = wIdx, let t = tIdx {
            if browser == "Safari" {
                return "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(t) of window \(w) to return do JavaScript \"\(escapedJS)\"\nend timeout\nend try\nend tell\nreturn \"NOT_PLAYING\"\n"
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
    
    func fetchDominantColor(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            let color = image.averageColor
            DispatchQueue.main.async { self.artworkDominantColor = color }
        }.resume()
    }
}
