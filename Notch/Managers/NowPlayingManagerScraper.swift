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
                    if self.allowedBrowsers.contains(name) { activeBrowsers.append(name) }
                    if name == "Spotify" && self.enableSpotify { isSpotifyNativeRunning = true }
                    if name == "Music" && self.enableAppleMusic { isAppleMusicRunning = true }
                }
            }
            
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
                } else if self.lastActiveBrowser == "AppleMusicNative" {
                    DispatchQueue.main.async {
                        if self.isPlaying { self.isPlaying = false }
                        self.refreshFetchTimerIfNeeded()
                    }
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
                            
                            -- ⚡️ THE FIX: Safely handles Spotify Native's 'Repeat One' panic
                            try
                                set rep to repeating
                                if rep then
                                    set loopState to "ALL"
                                else
                                    set loopState to "NONE"
                                end if
                            on error
                                set loopState to "ONE"
                            end try
                            
                            return tName & "|||" & tArtist & "|||" & tArt & "|||" & loopState & "|||" & tPos & "|||" & tDur
                        end if
                    end tell
                    return "NOT_PLAYING"
                    """
                if let res = NSAppleScript(source: spotScript)?.executeAndReturnError(nil).stringValue, res != "NOT_PLAYING", res != "NOT_FOUND" {
                    self.parseAndApplyResult(result: res + "|||Queue unavailable for Spotify Native", browser: "SpotifyNative")
                    return
                } else if self.lastActiveBrowser == "SpotifyNative" {
                    DispatchQueue.main.async {
                        if self.isPlaying { self.isPlaying = false }
                        self.refreshFetchTimerIfNeeded()
                    }
                }
            }
            
            if activeBrowsers.isEmpty {
                DispatchQueue.main.async {
                    if self.isPlaying { self.isPlaying = false }
                    self.refreshFetchTimerIfNeeded()
                    self.isFetching = false
                }
                return
            }
            if let last = self.lastActiveBrowser {
                let cleanLast = last.replacingOccurrences(of: "_YT", with: "").replacingOccurrences(of: "_YouTube Music", with: "").replacingOccurrences(of: "_Spotify Web", with: "")
                if activeBrowsers.contains(cleanLast) {
                    activeBrowsers.removeAll(where: { $0 == cleanLast })
                    activeBrowsers.insert(cleanLast, at: 0)
                }
            }
            
            let jsCode = "(function(){if(document.wasDiscarded||document.prerendering)return 'NOT_PLAYING';function pt(str){if(!str)return 0;var p=str.split(':');var s=0,m=1;while(p.length>0){s+=m*parseInt(p.pop(),10);m*=60;}return s;}var host=window.location.hostname;var active=null;var cTitle='',cArtist='',cImg='NO_IMAGE',cCurr=-1,cDur=-1,loopState='NONE',playlist='';if(host.includes('music.youtube.com')){active=document.querySelector('.html5-main-video');var tEl=document.querySelector('ytmusic-player-bar .title');var aEl=document.querySelector('ytmusic-player-bar .byline');if(tEl)cTitle=tEl.innerText;if(aEl)cArtist=aEl.innerText.split('•')[0].trim();var time=document.querySelector('.time-info.ytmusic-player-bar');if(time){var p=time.innerText.split('/');if(p.length===2){cCurr=pt(p[0]);cDur=pt(p[1]);}}var btns=document.querySelectorAll('ytmusic-player-bar button, ytmusic-player-bar tp-yt-paper-icon-button');for(var i=0;i<btns.length;i++){var lbl=(btns[i].getAttribute('aria-label')||btns[i].getAttribute('title')||'').toLowerCase();var html=btns[i].innerHTML;if(html.includes('17.293')||html.includes('21 10a1')||html.includes('M7 7h10')||lbl.includes('repeat')||lbl.includes('반복')){if(lbl.includes('one')||lbl.includes('1')||lbl.includes('한'))loopState='ONE';else if(lbl.includes('all')||lbl.includes('전체'))loopState='ALL';else if(lbl.includes('off')||lbl.includes('안함'))loopState='NONE';else loopState=(window.getComputedStyle(btns[i]).opacity<0.6||window.getComputedStyle(btns[i]).color==='rgb(144, 144, 144)')?'NONE':'ALL';break;}}try{var qItems=document.querySelectorAll('ytmusic-player-queue-item');var pArr=[];var start=0;for(var i=0;i<qItems.length;i++){if(qItems[i].hasAttribute('selected')||qItems[i].getAttribute('play-button-state')==='playing'){start=i;break;}}for(var j=start;j<qItems.length;j++){var tN=qItems[j].querySelector('.song-title, .title, yt-formatted-string[title]');var aN=qItems[j].querySelector('.byline');var iN=qItems[j].querySelector('img');var tText=tN?(tN.innerText||tN.getAttribute('title')||'').trim():'';var aText=aN?aN.innerText.replace(/\\\\n/g,'').trim():'Unknown';var iSrc=iN?(iN.src||''):'NO_IMAGE';if(tText){pArr.push(tText+'~~~'+aText+'~~~'+iSrc);}if(pArr.length>=15)break;}playlist=pArr.join('&&&');}catch(e){}}else if(host.includes('spotify.com')){active=document.querySelector('video, audio');var tEl=document.querySelector('[data-testid=context-item-info-title]');var aEl=document.querySelector('[data-testid=context-item-info-artist]');if(tEl)cTitle=tEl.innerText;if(aEl)cArtist=aEl.innerText;var cEl=document.querySelector('[data-testid=playback-position]');var dEl=document.querySelector('[data-testid=playback-duration]');if(cEl)cCurr=pt(cEl.innerText);if(dEl)cDur=pt(dEl.innerText);var sRep=document.querySelector('[data-testid=\"control-button-repeat\"]');if(sRep){var aLbl=(sRep.getAttribute('aria-label')||'').toLowerCase();var aChk=sRep.getAttribute('aria-checked');if(aLbl.includes('one')||aLbl.includes('1'))loopState='ONE';else if(aChk==='true'||aChk==='mixed'||aLbl.includes('disable'))loopState='ALL';else loopState='NONE';}}else if(host.includes('youtube.com')){active=document.querySelector('.html5-main-video');loopState=(active&&(active.loop||active.hasAttribute('loop')))?'ALL':'NONE';if(active&&active.duration>0.05){cDur=active.duration-0.05;}var attrTitle=document.querySelector('.ytVideoAttributeViewModelTitle')||document.querySelector('#title h1 yt-formatted-string');var attrArtist=document.querySelector('.ytVideoAttributeViewModelSubtitle')||document.querySelector('#owner-name a');if(attrTitle)cTitle=attrTitle.innerText.trim();if(attrArtist)cArtist=attrArtist.innerText.trim();try{var ytdItems=document.querySelectorAll('ytd-playlist-panel-video-renderer');var ytdArr=[];var ytdStart=0;for(var k=0;k<ytdItems.length;k++){if(ytdItems[k].hasAttribute('selected')){ytdStart=k;break;}}for(var l=ytdStart;l<ytdItems.length;l++){var yT=ytdItems[l].querySelector('#video-title');var yA=ytdItems[l].querySelector('#byline');var yI=ytdItems[l].querySelector('img');var iSrc=yI?(yI.src||''):'NO_IMAGE';if(yT&&yT.innerText.trim()){ytdArr.push(yT.innerText.trim()+'~~~'+(yA?yA.innerText.trim():'Unknown')+'~~~'+iSrc);}if(ytdArr.length>=15)break;}playlist=ytdArr.join('&&&');}catch(e){}}else{var media=document.querySelectorAll('video, audio');for(var i=0;i<media.length;i++){if(!media[i].paused&&media[i].currentTime>0){active=media[i];break;}}if(!active&&media.length>0)active=media[0];if(active){loopState=(active.loop||active.hasAttribute('loop'))?'ALL':'NONE';}}var isPlaying = (active && !active.paused && !active.ended && active.currentTime > 0);if (!active && navigator.mediaSession && navigator.mediaSession.playbackState === 'playing') isPlaying = true;if (isPlaying) {var title=cTitle||document.title;var artist=cArtist||'EMPTY_ARTIST';var curr=cCurr!==-1?cCurr:(active?active.currentTime:0);var dur=cDur!==-1&&isNaN(cDur)===false&&cDur!==0?cDur:(active?(active.duration||1):1);if(navigator.mediaSession&&navigator.mediaSession.metadata){var m=navigator.mediaSession.metadata;if(!cTitle&&m.title)title=m.title;if(artist==='EMPTY_ARTIST'&&m.artist)artist=m.artist;if(cImg==='NO_IMAGE'&&m.artwork&&m.artwork.length>0)cImg=m.artwork[m.artwork.length-1].src;}var hostFlag=host.includes('music.youtube.com')?'YOUTUBE_MUSIC':(host.includes('youtube.com')?'YOUTUBE_STANDARD':(host.includes('spotify.com')?'SPOTIFY_WEB':'OTHER'));return title+'|||'+artist+'|||'+cImg+'|||'+loopState+'|||'+curr+'|||'+dur+'@@@'+hostFlag+'|||'+playlist;}return 'NOT_PLAYING';})();"
            let shouldUseDetailedScript = self.shouldUseDetailedMediaScrape
            if shouldUseDetailedScript {
                self.markDetailedMediaScrapeRun()
            }
            let effectiveJSCode = shouldUseDetailedScript ? jsCode : self.lightweightBrowserSnapshotScript()
            
            // ⚡️ FAST PATH: Instantly check the last known active tab
            if let rawBrowser = self.lastActiveBrowser, let wIdx = self.lastWindowIndex, let tIdx = self.lastTabIndex {
                let cleanBrowser = rawBrowser.replacingOccurrences(of: "_YT", with: "").replacingOccurrences(of: "_YouTube Music", with: "").replacingOccurrences(of: "_Spotify Web", with: "")
                if activeBrowsers.contains(cleanBrowser) {
                    let fastScript = self.buildAppleScript(browser: cleanBrowser, jsCode: effectiveJSCode, wIdx: wIdx, tIdx: tIdx)
                    if let result = NSAppleScript(source: fastScript)?.executeAndReturnError(nil).stringValue {
                        if result != "NOT_PLAYING" && !result.isEmpty {
                            // Still playing on the same tab! Process it and we are done.
                            self.parseAndApplyResult(result: result + "|||" + rawBrowser, browser: rawBrowser)
                            return
                        } else if result == "NOT_PLAYING" {
                            if !self.isNotchExpandedForPolling {
                                DispatchQueue.main.async {
                                    if self.isPlaying { self.isPlaying = false }
                                    self.refreshFetchTimerIfNeeded()
                                    self.isFetching = false
                                }
                                return
                            }
                            // Expanded mode can afford a full loop in case another tab started playing.
                        } else {
                            self.clearBrowserFastPath(browser: rawBrowser, windowIndex: wIdx, tabIndex: tIdx)
                        }
                    } else {
                        self.clearBrowserFastPath(browser: rawBrowser, windowIndex: wIdx, tabIndex: tIdx)
                    }
                }
            }
            
            // FULL LOOP: Only probe known media tabs; generic background tabs can be suspended by Memory Saver.
            guard self.shouldRunFullBrowserDiscovery else {
                DispatchQueue.main.async {
                    if self.isPlaying { self.isPlaying = false }
                    self.refreshFetchTimerIfNeeded()
                    self.isFetching = false
                }
                return
            }
            self.markFullBrowserDiscoveryRun()

            self.runFullAppleScriptLoop(jsCode: effectiveJSCode) { result in
                if let res = result {
                    self.parseAndApplyResult(result: res, browser: res.components(separatedBy: "|||").last ?? "Unknown")
                } else {
                    DispatchQueue.main.async {
                        if self.isPlaying { self.isPlaying = false }
                        self.refreshFetchTimerIfNeeded()
                        self.isFetching = false
                    }
                }
            }
        }
    }
    
    func runFullAppleScriptLoop(jsCode: String, completion: @escaping (String?) -> Void) {
        let runningApps = NSWorkspace.shared.runningApplications
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

    private func clearBrowserFastPath(browser: String, windowIndex: Int, tabIndex: Int) {
        DispatchQueue.main.async {
            guard self.lastActiveBrowser == browser,
                  self.lastWindowIndex == windowIndex,
                  self.lastTabIndex == tabIndex else {
                return
            }

            self.lastWindowIndex = nil
            self.lastTabIndex = nil
            UserDefaults.standard.removeObject(forKey: "lastWindowIndex")
            UserDefaults.standard.removeObject(forKey: "lastTabIndex")
        }
    }
    
    private func parseAndApplyResult(result: String, browser: String) {
        DispatchQueue.main.async {
            let components = result.components(separatedBy: "|||")
            guard components.count >= 6 else { self.isFetching = false; return }
            
            if !self.isPlaying { self.isPlaying = true }
            self.refreshFetchTimerIfNeeded()
            let rawTitle = components[0].replacingOccurrences(of: " - YouTube Music", with: "").replacingOccurrences(of: " - YouTube", with: "").replacingOccurrences(of: " | Spotify", with: "")
            let rawArtist = components[1] == "EMPTY_ARTIST" ? "" : components[1]
            let imgString = components[2]
            let loopString = components[3]
            let currString = components[4]
            
            let durParts = components[5].components(separatedBy: "@@@")
            let durString = durParts[0]
            let hostFlag = durParts.count > 1 ? durParts[1] : "OTHER"
            let isStandardYT = hostFlag == "YOUTUBE_STANDARD"
            
            var playlistString = ""
            if components.count >= 7 { playlistString = components[6] }
            
            var nextActiveBrowser = self.lastActiveBrowser
            var nextWindowIndex = self.lastWindowIndex
            var nextTabIndex = self.lastTabIndex

            if browser == "SpotifyNative" || browser == "AppleMusicNative" {
                nextActiveBrowser = browser
                nextWindowIndex = nil
                nextTabIndex = nil
            } else if components.count >= 9 {
                if hostFlag == "YOUTUBE_STANDARD" {
                    nextActiveBrowser = browser + "_YT"
                } else if hostFlag == "YOUTUBE_MUSIC" {
                    nextActiveBrowser = browser + "_YouTube Music"
                } else if hostFlag == "SPOTIFY_WEB" {
                    nextActiveBrowser = browser + "_Spotify Web"
                } else {
                    nextActiveBrowser = browser
                }
                nextWindowIndex = Int(components[7])
                nextTabIndex = Int(components[8])
            }
            
            // ⚡️ PERSIST STATE FOR WAKE/RESTART
            if self.lastActiveBrowser != nextActiveBrowser {
                self.lastActiveBrowser = nextActiveBrowser
                UserDefaults.standard.set(nextActiveBrowser, forKey: "lastActiveBrowser")
            }
            if self.lastWindowIndex != nextWindowIndex {
                self.lastWindowIndex = nextWindowIndex
                if let w = nextWindowIndex {
                    UserDefaults.standard.set(w, forKey: "lastWindowIndex")
                } else {
                    UserDefaults.standard.removeObject(forKey: "lastWindowIndex")
                }
            }
            if self.lastTabIndex != nextTabIndex {
                self.lastTabIndex = nextTabIndex
                if let t = nextTabIndex {
                    UserDefaults.standard.set(t, forKey: "lastTabIndex")
                } else {
                    UserDefaults.standard.removeObject(forKey: "lastTabIndex")
                }
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
            if !playlistString.isEmpty, self.playlist != uniqueTracks { self.playlist = uniqueTracks }
            
            let newDuration = Double(durString) ?? 1.0
            if abs(self.duration - newDuration) > 0.25 { self.duration = newDuration }
            
            let identifier = rawTitle + rawArtist
            if self.internalSongIdentifier != identifier {
                self.internalSongIdentifier = identifier
                
                if isStandardYT && self.duration > 360.0 {
                    DispatchQueue.main.async {
                        self.lyrics = []
                        self.activeLyricIndex = 0
                        self.currentSongLyricOffset = 0.0
                        self.lyricsDisabledForCurrentSong = false
                        self.isSearchingLyrics = false
                    }
                } else {
                    self.fetchLyricsEngine(title: rawTitle, artist: rawArtist)
                }
                
                if self.currentTime != 0.0 { self.currentTime = 0.0 }
                
                if browser == "AppleMusicNative" {
                    self.fetchAppleMusicArtwork(title: rawTitle, artist: rawArtist)
                }
            }
            
            let displayString = rawArtist.isEmpty ? rawTitle : "\(rawTitle) - \(rawArtist)"
            if self.currentSong != displayString { self.currentSong = displayString }
            
            if browser != "AppleMusicNative" {
                if imgString != "NO_IMAGE", let url = URL(string: imgString) {
                    if self.artworkURL != url { self.artworkURL = url; self.fetchDominantColor(from: url) }
                } else {
                    if self.artworkURL != nil {
                        self.artworkURL = nil
                        self.artworkDominantColor = .white
                    }
                }
            }
            
            let newTime = Double(currString) ?? 0.0
            if abs(self.currentTime - newTime) > 1.5 { self.currentTime = newTime }
            
            if Date().timeIntervalSince(self.lastLoopToggleTime) > 2.0 {
                let nextLoopMode = loopString == "ALL" ? 1 : (loopString == "ONE" ? 2 : 0)
                if self.loopMode != nextLoopMode { self.loopMode = nextLoopMode }
            }
            self.isFetching = false
        }
    }
    
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
            
            let highResUrlString = artwork100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            
            if let highResUrl = URL(string: highResUrlString) {
                DispatchQueue.main.async {
                    self.artworkURL = highResUrl
                    self.fetchDominantColor(from: highResUrl)
                }
            }
        }.resume()
    }

    private func lightweightBrowserSnapshotScript() -> String {
        "(function(){if(document.wasDiscarded||document.prerendering)return 'NOT_PLAYING';function pt(str){if(!str)return 0;var p=str.split(':');var s=0,m=1;while(p.length>0){s+=m*parseInt(p.pop(),10)||0;m*=60;}return s;}var host=window.location.hostname;var active=null,title='',artist='',img='NO_IMAGE',curr=-1,dur=-1,loopState='NONE';if(host.includes('youtube.com')){active=document.querySelector('.html5-main-video');if(active&&active.duration>0.05)dur=active.duration-0.05;if(active)loopState=(active.loop||active.hasAttribute('loop'))?'ALL':'NONE';if(host.includes('music.youtube.com')){var tEl=document.querySelector('ytmusic-player-bar .title');var aEl=document.querySelector('ytmusic-player-bar .byline');var time=document.querySelector('.time-info.ytmusic-player-bar');if(tEl)title=tEl.innerText.trim();if(aEl)artist=aEl.innerText.split('•')[0].trim();if(time){var tp=time.innerText.split('/');if(tp.length===2){curr=pt(tp[0]);dur=pt(tp[1]);}}}else{var ytTitle=document.querySelector('.ytVideoAttributeViewModelTitle')||document.querySelector('#title h1 yt-formatted-string');var ytArtist=document.querySelector('.ytVideoAttributeViewModelSubtitle')||document.querySelector('#owner-name a');if(ytTitle)title=ytTitle.innerText.trim();if(ytArtist)artist=ytArtist.innerText.trim();}}else if(host.includes('spotify.com')){active=document.querySelector('video, audio');var sTitle=document.querySelector('[data-testid=context-item-info-title]');var sArtist=document.querySelector('[data-testid=context-item-info-artist]');var cEl=document.querySelector('[data-testid=playback-position]');var dEl=document.querySelector('[data-testid=playback-duration]');if(sTitle)title=sTitle.innerText.trim();if(sArtist)artist=sArtist.innerText.trim();if(cEl)curr=pt(cEl.innerText);if(dEl)dur=pt(dEl.innerText);}else{var media=document.querySelectorAll('video, audio');for(var i=0;i<media.length;i++){if(!media[i].paused&&media[i].currentTime>0){active=media[i];break;}}if(!active&&media.length>0)active=media[0];if(active)loopState=(active.loop||active.hasAttribute('loop'))?'ALL':'NONE';}var isPlaying=(active&&!active.paused&&!active.ended&&active.currentTime>0);if(!isPlaying&&navigator.mediaSession&&navigator.mediaSession.playbackState==='playing')isPlaying=true;if(!isPlaying)return 'NOT_PLAYING';if(active){if(curr===-1)curr=active.currentTime||0;if(dur===-1||isNaN(dur)||dur===0)dur=active.duration||1;}if(navigator.mediaSession&&navigator.mediaSession.metadata){var m=navigator.mediaSession.metadata;if(!title&&m.title)title=m.title;if(!artist&&m.artist)artist=m.artist;if(m.artwork&&m.artwork.length>0)img=m.artwork[m.artwork.length-1].src;}if(!title)title=document.title;if(!artist)artist='EMPTY_ARTIST';var hostFlag=host.includes('music.youtube.com')?'YOUTUBE_MUSIC':(host.includes('youtube.com')?'YOUTUBE_STANDARD':(host.includes('spotify.com')?'SPOTIFY_WEB':'OTHER'));return title+'|||'+artist+'|||'+img+'|||'+loopState+'|||'+curr+'|||'+dur+'@@@'+hostFlag+'|||';})();"
    }
    
    func buildAppleScript(browser: String, jsCode: String, wIdx: Int? = nil, tIdx: Int? = nil) -> String {
        let escapedJS = jsCode.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        if let w = wIdx, let t = tIdx {
            if browser == "Safari" {
                return "tell application \"Safari\"\ntry\nwith timeout of 1 second\ntell tab \(t) of window \(w) to return do JavaScript \"\(escapedJS)\"\nend timeout\nend try\nend tell\nreturn \"NOT_PLAYING\"\n"
            } else {
                return """
                tell application "\(browser)"
                    try
                        set tabLoading to false
                        try
                            set tabLoading to loading of tab \(t) of window \(w)
                        end try
                        if tabLoading then return "NOT_PLAYING"
                        with timeout of 1 second
                            tell tab \(t) of window \(w) to return execute javascript "\(escapedJS)"
                        end timeout
                    end try
                end tell
                return "NOT_PLAYING"
                """
            }
        } else {
            if browser == "Safari" {
                return """
                tell application "Safari"
                    set wCount to count of windows
                    repeat with wIdx from 1 to wCount
                        set tCount to count of tabs of window wIdx
                        repeat with tIdx from 1 to tCount
                            set tabResult to "NOT_PLAYING"
                            set tabURL to ""
                            set shouldScan to false
                            try
                                set tabURL to URL of tab tIdx of window wIdx as text
                                if tabURL contains "youtube.com" or tabURL contains "youtu.be" or tabURL contains "spotify.com" or tabURL contains "music.apple.com" or tabURL contains "soundcloud.com" or tabURL contains "bandcamp.com" then set shouldScan to true
                            end try
                            if shouldScan then
                                try
                                    with timeout of 1 second
                                        tell tab tIdx of window wIdx to set tabResult to do JavaScript "\(escapedJS)"
                                    end timeout
                                on error
                                    set tabResult to "NOT_PLAYING"
                                end try
                                if tabResult is not "NOT_PLAYING" and tabResult is not "" and tabResult is not missing value then
                                    return tabResult as string & "|||" & wIdx & "|||" & tIdx
                                end if
                            end if
                        end repeat
                    end repeat
                end tell
                return "NOT_PLAYING"
                """
            } else {
                return """
                tell application "\(browser)"
                    set wCount to count of windows
                    repeat with wIdx from 1 to wCount
                        set tCount to count of tabs of window wIdx
                        repeat with tIdx from 1 to tCount
                            set tabResult to "NOT_PLAYING"
                            set tabURL to ""
                            set shouldScan to false
                            try
                                set tabURL to URL of tab tIdx of window wIdx as text
                                if tabURL contains "youtube.com" or tabURL contains "youtu.be" or tabURL contains "spotify.com" or tabURL contains "music.apple.com" or tabURL contains "soundcloud.com" or tabURL contains "bandcamp.com" then set shouldScan to true
                                set tabLoading to false
                                try
                                    set tabLoading to loading of tab tIdx of window wIdx
                                end try
                                if tabLoading then set shouldScan to false
                            end try
                            if shouldScan then
                                try
                                    with timeout of 1 second
                                        tell tab tIdx of window wIdx to set tabResult to execute javascript "\(escapedJS)"
                                    end timeout
                                on error
                                    set tabResult to "NOT_PLAYING"
                                end try
                                if tabResult is not "NOT_PLAYING" and tabResult is not "" and tabResult is not missing value then
                                    return tabResult as string & "|||" & wIdx & "|||" & tIdx
                                end if
                            end if
                        end repeat
                    end repeat
                end tell
                return "NOT_PLAYING"
                """
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
