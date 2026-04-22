import SwiftUI
import AuthenticationServices
import CryptoKit
import Combine

class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()
    
    @AppStorage("spotify_access_token") var accessToken: String = ""
    @AppStorage("spotify_refresh_token") var refreshToken: String = ""
    @AppStorage("spotify_token_expiry") var tokenExpiry: Double = 0
    
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var currentQueue: [SpotifyTrack] = []
    @Published var currentlyPlaying: SpotifyTrack?
    
    private let clientID = "46f0d686e3194a918e5396e0715dd599" // ⚡️ Using your previously mentioned ID
    private let redirectURI = "wavenotch://callback"
    private let scopes = "user-read-playback-state user-modify-playback-state playlist-read-private playlist-read-collaborative"
    
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String = ""
    
    func authenticate(completion: @escaping (Bool) -> Void) {
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
    
    // MARK: - Player Controls
    
    func play(uri: String? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "PUT", endpoint: "play", body: uri != nil ? ["uris": [uri!]] : nil, completion: completion)
    }
    
    func pause(completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "PUT", endpoint: "pause", completion: completion)
    }
    
    func skipNext(completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "POST", endpoint: "next", completion: completion)
    }
    
    func skipPrevious(completion: @escaping (Bool) -> Void = { _ in }) {
        performPlayerRequest(method: "POST", endpoint: "previous", completion: completion)
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
                        self.playlists = response.items
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
            
            URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data = data else { return }
                if let response = try? JSONDecoder().decode(SpotifyQueue.self, from: data) {
                    DispatchQueue.main.async {
                        self.currentlyPlaying = response.currently_playing
                        self.currentQueue = response.queue
                    }
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
