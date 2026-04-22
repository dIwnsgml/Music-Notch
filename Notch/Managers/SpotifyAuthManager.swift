import AuthenticationServices
import SwiftUI
import Combine
import CryptoKit

class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()
    
    @AppStorage("spotifyAccessToken") var accessToken: String = ""
    @AppStorage("spotifyRefreshToken") var refreshToken: String = ""
    
    @Published var authError: Bool = false
    
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var spotifyQueue: [SpotifyTrack] = []
    
    let clientID = "46f0d686e3194a918e5396e0715dd599"
    let redirectURI = "wavenotch://callback" // You must register this in Spotify Dev Portal
    
    private var currentVerifier: String = ""
    
    func authenticate() {
        let verifier = PKCE.generateCodeVerifier()
        self.currentVerifier = verifier
        let challenge = PKCE.generateCodeChallenge(verifier: verifier)
        
        let authURLString = "https://accounts.spotify.com/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&code_challenge_method=S256&code_challenge=\(challenge)&scope=user-read-playback-state%20user-modify-playback-state%20playlist-read-private"
        
        guard let authURL = URL(string: authURLString) else { return }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "wavenotch") { callbackURL, error in
            guard error == nil, let url = callbackURL else { return }
            
            // Extract the 'code' from the URL and exchange it for a token
            if let code = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value {
                self.exchangeCodeForToken(code: code, verifier: self.currentVerifier)
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    private func exchangeCodeForToken(code: String, verifier: String) {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let rawString = String(data: data, encoding: .utf8) {
                print("Spotify Token Response: \(rawString)")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    if let access = json["access_token"] as? String {
                        self.accessToken = access
                        print("Spotify Access Token Updated")
                        self.fetchUserPlaylists() // ⚡️ Fetch immediately after auth
                    }
                    if let refresh = json["refresh_token"] as? String {
                        self.refreshToken = refresh
                    }
                }
            }
        }.resume()
    }
    
    func fetchUserPlaylists() {
        guard !accessToken.isEmpty else { return }
        
        let url = URL(string: "https://api.spotify.com/v1/me/playlists")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            // ⚡️ THE FIX: Catch the expired token
            if httpResponse.statusCode == 401 {
                print("Token expired. Attempting refresh...")
                self.refreshAccessToken { success in
                    if success {
                        self.fetchUserPlaylists()
                    } else {
                        DispatchQueue.main.async {
                            self.authError = true // ⚡️ Tell the UI to stop spinning!
                        }
                    }
                }
                return
            }
            
            // Only attempt to decode if we got a successful 200 OK status
            guard httpResponse.statusCode == 200, let data = data else {
                print("Spotify API Error: \(httpResponse.statusCode)")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(SpotifyPlaylistResponse.self, from: data)
                DispatchQueue.main.async {
                    self.playlists = decodedResponse.items
                }
            } catch {
                print("Failed to decode playlists: \(error)")
            }
        }.resume()
    }
    
    func fetchSpotifyQueue() {
        guard !accessToken.isEmpty else { return }
        
        let url = URL(string: "https://api.spotify.com/v1/me/player/queue")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 401 {
                self.refreshAccessToken { success in
                    if success { self.fetchSpotifyQueue() }
                }
                return
            }
            
            guard httpResponse.statusCode == 200, let data = data else { return }
            
            do {
                let decodedResponse = try JSONDecoder().decode(SpotifyQueueResponse.self, from: data)
                DispatchQueue.main.async {
                    self.spotifyQueue = decodedResponse.queue
                }
            } catch {
                print("Failed to decode Spotify Queue: \(error)")
            }
        }.resume()
    }
    
    func playSpotifyContext(uri: String) {
        guard !accessToken.isEmpty else { return }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["context_uri": uri]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func playSpotifyTrack(uri: String) {
        guard !accessToken.isEmpty else { return }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["uris": [uri]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // ⚡️ Silently grabs a new access token using your saved refresh token
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard !refreshToken.isEmpty else {
            completion(false)
            return
        }
        
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // PKCE Refresh only requires the client_id
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ]
        
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                
                print("Failed to refresh token.")
                completion(false)
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let newAccessToken = json["access_token"] as? String {
                
                DispatchQueue.main.async {
                    self.accessToken = newAccessToken
                    // Sometimes Spotify issues a new refresh token too, update it if they do
                    if let newRefreshToken = json["refresh_token"] as? String {
                        self.refreshToken = newRefreshToken
                    }
                    completion(true)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? NSWindow()
    }
}

struct PKCE {
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            buffer[i] = UInt8.random(in: 0...255)
        }
        let data = Data(buffer)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    static func generateCodeChallenge(verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
