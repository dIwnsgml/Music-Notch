import SwiftUI
import AuthenticationServices
import CryptoKit
import Combine

class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()
    
    @AppStorage("spotify_access_token") var accessToken: String = ""
    @AppStorage("spotify_refresh_token") var refreshToken: String = ""
    @AppStorage("spotify_token_expiry") var tokenExpiry: Double = 0
    @AppStorage("spotify_client_id") var userClientID: String = "" // ⚡️ REQUIRED: Users must provide their own
    
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var currentQueue: [SpotifyTrack] = []
    @Published var currentQueueItems: [SpotifyQueueItem] = []
    @Published var currentlyPlaying: SpotifyTrack?
    
    private var clientID: String {
        userClientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var hasValidClientID: Bool {
        let trimmed = clientID
        guard trimmed.count == 32 else { return false }
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return trimmed.rangeOfCharacter(from: hexCharacterSet.inverted) == nil
    }
    
    private let redirectURI = "wavenotch://callback"
    private let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-read-collaborative user-library-read"
    
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String = ""
    
    override init() {
        super.init()
        
        // ⚡️ URL Callback Listener
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SpotifyAuthCallback"), object: nil, queue: .main) { notification in
            if let code = notification.object as? String {
                self.exchangeCodeForToken(code: code) { _ in }
            }
        }
    }
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        guard !clientID.isEmpty else {
            print("⚠️ Spotify Error: Client ID is missing.")
            completion(false)
            return
        }
        
        // 1. Generate PKCE Verifier and Challenge
        self.codeVerifier = generateRandomString(length: 64)
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // 2. Construct Auth URL
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "scope", value: scopes)
        ]
        
        guard let authURL = components.url else {
            completion(false)
            return
        }
        
        // 3. Start Auth Session
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "wavenotch") { callbackURL, error in
            if let error = error {
                print("Spotify Auth Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let callbackURL = callbackURL,
                  let code = URLComponents(string: callbackURL.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                completion(false)
                return
            }
            
            self.exchangeCodeForToken(code: code, completion: completion)
        }
        
        authSession?.presentationContextProvider = self
        authSession?.start()
    }
    
    private func exchangeCodeForToken(code: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleTokenResponse(data: data, error: error, completion: completion)
        }.resume()
    }
    
    func refreshAccessTokenIfNeeded(completion: @escaping (Bool) -> Void) {
        guard !refreshToken.isEmpty else {
            completion(false)
            return
        }
        
        // Check if token is expired or expiring soon (5 min buffer)
        if Date().timeIntervalSince1970 < (tokenExpiry - 300) {
            completion(true)
            return
        }
        
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleTokenResponse(data: data, error: error, completion: completion)
        }.resume()
    }
    
    private func handleTokenResponse(data: Data?, error: Error?, completion: @escaping (Bool) -> Void) {
        guard let data = data, error == nil else {
            completion(false)
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let access = json["access_token"] as? String {
                
                DispatchQueue.main.async {
                    self.accessToken = access
                    if let refresh = json["refresh_token"] as? String {
                        self.refreshToken = refresh
                    }
                    if let expires = json["expires_in"] as? Int {
                        self.tokenExpiry = Date().timeIntervalSince1970 + Double(expires)
                    }
                    completion(true)
                }
            } else {
                completion(false)
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - Automation
    
    func automateSetup() {
        let browser = getPreferredBrowser()
        let isSafari = browser == "Safari"
        
        let jsCode = """
        (function() {
            function setNativeValue(element, value) {
                if (!element) return;
                var valueSetter = Object.getOwnPropertyDescriptor(element, 'value').set;
                var prototype = Object.getPrototypeOf(element);
                var prototypeValueSetter = Object.getOwnPropertyDescriptor(prototype, 'value').set;
                if (valueSetter && valueSetter !== prototypeValueSetter) {
                    prototypeValueSetter.call(element, value);
                } else {
                    valueSetter.call(element, value);
                }
                element.dispatchEvent(new Event('input', { bubbles: true }));
                element.dispatchEvent(new Event('change', { bubbles: true }));
            }

            var checkExist = setInterval(function() {
                /* 1. Developer Terms */
                var acceptedCheck = document.getElementById('accepted');
                if (acceptedCheck) {
                    if (!acceptedCheck.checked) acceptedCheck.click();
                    var btns = Array.from(document.querySelectorAll('button[data-encore-id=\"buttonPrimary\"]'));
                    var acceptBtn = btns.find(b => b.innerText.includes('Accept'));
                    if (acceptBtn) acceptBtn.click();
                    return;
                }
                
                /* 2. Create App Form */
                var nameInput = document.getElementById('name');
                if (nameInput && nameInput.value !== 'WaveNotch') {
                    setNativeValue(nameInput, 'WaveNotch');
                    
                    var descInput = document.getElementById('description');
                    setNativeValue(descInput, 'Dynamic Island for Mac');
                    
                    var uriInput = document.getElementById('newRedirectUri');
                    if (uriInput) {
                        setNativeValue(uriInput, 'wavenotch://callback');
                        setTimeout(() => {
                            var addButton = document.querySelector('button[aria-label=\"Add redirect URI\"]');
                            if (addButton) addButton.click();
                        }, 200);
                    }
                    
                    /* API Checkboxes & Terms */
                    ['apis-used-1', 'apis-used-4', 'termsAccepted'].forEach(id => {
                        var el = document.getElementById(id);
                        if (el && !el.checked) el.click();
                    });
                    
                    /* Final Save Button */
                    setTimeout(() => {
                        var saveBtn = document.querySelector('button[type=\"submit\"]');
                        if (!saveBtn) {
                            var btns = Array.from(document.querySelectorAll('button[data-encore-id=\"buttonPrimary\"]'));
                            saveBtn = btns.find(b => b.textContent && b.textContent.includes('Save'));
                        }
                        if (saveBtn) saveBtn.click();
                    }, 1500);
                }
                
                /* 3. Stop interval if client ID is visible */
                var clientIdSpan = document.querySelector('span[id=\"client-id\"]');
                if (clientIdSpan && clientIdSpan.innerText) {
                    clearInterval(checkExist);
                }
            }, 1000);
        })();
        """.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        
        let fetchIdJsCode = """
        (function() {
            var spans = Array.from(document.querySelectorAll('span'));
            var targetSpan = spans.find(s => {
                var txt = s.innerText ? s.innerText.trim() : '';
                return txt.length === 32 && /^[a-f0-9]{32}$/i.test(txt);
            });
            if (targetSpan) {
                return targetSpan.innerText.trim();
            }
            var settingsBtn = Array.from(document.querySelectorAll('a, button, span')).find(el => el.innerText && el.innerText.includes('Settings'));
            if (settingsBtn) settingsBtn.click();
            return '';
        })();
        """.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        
        let script: String
        if isSafari {
            script = """
            tell application "Safari"
                activate
                if not (exists window 1) then make new window
                set URL of current tab of window 1 to "https://developer.spotify.com/dashboard/create"
                delay 3
                do JavaScript "\(jsCode)" in current tab of window 1
                
                set clientID to ""
                repeat 30 times
                    delay 1
                    set clientID to do JavaScript "\(fetchIdJsCode)" in current tab of window 1
                    if clientID is not missing value and clientID is not "" then exit repeat
                end repeat
                return clientID
            end tell
            """
        } else {
            script = """
            tell application "\(browser)"
                activate
                if not (exists window 1) then make new window
                set URL of active tab of window 1 to "https://developer.spotify.com/dashboard/create"
                delay 3
                tell active tab of window 1 to execute javascript "\(jsCode)"
                
                set clientID to ""
                repeat 30 times
                    delay 1
                    tell active tab of window 1
                        set clientID to execute javascript "\(fetchIdJsCode)"
                    end tell
                    if clientID is not missing value and clientID is not "" then exit repeat
                end repeat
                return clientID
            end tell
            """
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                let result = scriptObject.executeAndReturnError(&error)
                if let id = result.stringValue, !id.isEmpty {
                    DispatchQueue.main.async {
                        self.userClientID = id
                        print("Successfully auto-grabbed Client ID: \(id)")
                    }
                } else if let err = error {
                    print("AppleScript Error: \(err)")
                }
            }
        }
    }
    
    private func getPreferredBrowser() -> String {
        if UserDefaults.standard.bool(forKey: "enableChrome") { return "Google Chrome" }
        if UserDefaults.standard.bool(forKey: "enableSafari") { return "Safari" }
        if UserDefaults.standard.bool(forKey: "enableBrave") { return "Brave Browser" }
        if UserDefaults.standard.bool(forKey: "enableEdge") { return "Microsoft Edge" }
        return "Safari"
    }
    
    // MARK: - Player Controls
    
    func playContext(uri: String, completion: @escaping (Bool) -> Void = { _ in }) {
        let body: [String: Any] = [
            "context_uri": uri,
            "offset": ["position": 0]
        ]
        
        performPlayerRequest(method: "PUT", endpoint: "play", body: body) { success in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.fetchQueue() }
            }
            completion(success)
        }
    }
    
    func skipToQueueItem(index: Int) {
        // Spotify API allows us to pass up to 100 URIs and start at a specific offset.
        // By passing the entire current queue and telling it to start at `index`,
        // we guarantee it plays the correct song immediately (even if Shuffle is on)
        // and we preserve the rest of the queue context instead of truncating it.
        let uris = currentQueueItems.map { $0.track.uri }
        let body: [String: Any] = [
            "uris": uris,
            "offset": ["position": index]
        ]
        
        performPlayerRequest(method: "PUT", endpoint: "play", body: body) { success in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.fetchQueue() }
            }
        }
    }
    
    func playTracks(uris: [String], completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "PUT", endpoint: "play", body: ["uris": uris]) { success in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.fetchQueue() }
            }
            completion(success)
        }
    }
    
    func play(completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "PUT", endpoint: "play", completion: completion)
    }
    
    func pause(completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "PUT", endpoint: "pause", completion: completion)
    }
    
    func skipNext(completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "POST", endpoint: "next", completion: completion)
    }
    
    func fetchPlaylists() {
        refreshAccessTokenIfNeeded { success in
            guard success else { return }
            
            let url = URL(string: "https://api.spotify.com/v1/me/playlists")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data = data else { return }
                if let response = try? JSONDecoder().decode(SpotifyPlaylistResponse.self, from: data) {
                    DispatchQueue.main.async {
                        if self.playlists != response.items {
                            self.playlists = response.items
                        }
                    }
                }
            }.resume()
        }
    }
    
    func fetchQueue() {
        refreshAccessTokenIfNeeded { success in
            guard success else { return }
            
            let url = URL(string: "https://api.spotify.com/v1/me/player/queue")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else { return }
                
                // ⚡️ Log the status code for debugging
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        print("Spotify Queue API Error Status: \(httpResponse.statusCode)")
                        return
                    }
                }
                
                if let response = try? JSONDecoder().decode(SpotifyQueue.self, from: data) {
                    DispatchQueue.main.async {
                        if self.currentlyPlaying != response.currently_playing {
                            self.currentlyPlaying = response.currently_playing
                        }
                        if self.currentQueue != response.queue {
                            self.currentQueue = response.queue
                        }

                        let queueItems = response.queue.enumerated().map { (index, track) in
                            SpotifyQueueItem(id: "\(index)-\(track.uri)", track: track)
                        }
                        if self.currentQueueItems != queueItems {
                            self.currentQueueItems = queueItems
                        }
                    }
                } else {
                    print("Failed to decode Spotify Queue JSON")
                }
            }.resume()
        }
    }
    
    private func performPlayerRequest(method: String, endpoint: String, body: [String: Any]? = nil, completion: @escaping (Bool) -> Void) {
        refreshAccessTokenIfNeeded { success in
            guard success else {
                completion(false)
                return
            }
            
            let url = URL(string: "https://api.spotify.com/v1/me/player/\(endpoint)")!
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
            
            if let body = body {
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            URLSession.shared.dataTask(with: request) { _, response, _ in
                let success = (response as? HTTPURLResponse)?.statusCode == 204 || (response as? HTTPURLResponse)?.statusCode == 200
                completion(success)
            }.resume()
        }
    }
    
    // MARK: - PKCE Helpers
    
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .utf8)!
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64URLEncodedString()
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSWindow()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
