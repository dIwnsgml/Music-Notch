import SwiftUI
import AuthenticationServices
import Combine
import CryptoKit

class YouTubeMusicManager: NSObject, ObservableObject {
    static let shared = YouTubeMusicManager()
    
    @AppStorage("yt_access_token") var accessToken: String = ""
    @AppStorage("yt_refresh_token") var refreshToken: String = ""
    @AppStorage("yt_token_expiry") var tokenExpiry: Double = 0
    
    @Published var playlists: [YTPlaylist] = []
    @Published var currentPlaylistTracks: [YTQueueItem] = []
    @Published var isFetching = false
    @Published var isAuthenticated = false
    
    private let clientID = "989490326013-4ukfahi6t9cplb3mujovrrbtb1onoif0.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.989490326013-4ukfahi6t9cplb3mujovrrbtb1onoif0:/youtube-callback" // ⚡️ Different path!
    private let scopes = "https://www.googleapis.com/auth/youtube.readonly"
    
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String = ""
    
    override init() {
        super.init()
        self.isAuthenticated = !accessToken.isEmpty
        
        if isAuthenticated {
            fetchPlaylists()
        }
        
        // ⚡️ URL Callback Listener
        NotificationCenter.default.addObserver(forName: NSNotification.Name("YouTubeAuthCallback"), object: nil, queue: .main) { notification in
            if let code = notification.object as? String {
                self.exchangeCodeForToken(code: code) { _ in }
            }
        }
    }
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        self.codeVerifier = generateRandomString(length: 64)
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        let reversedID = "com.googleusercontent.apps.989490326013-4ukfahi6t9cplb3mujovrrbtb1onoif0"
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authURL = components.url else {
            completion(false)
            return
        }
        
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: reversedID) { callbackURL, error in
            if let error = error {
                print("YT Auth Error: \(error.localizedDescription)")
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
        let url = URL(string: "https://oauth2.googleapis.com/token")!
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
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            self.handleTokenResponse(data: data, error: error, completion: completion)
        }.resume()
    }
    
    func refreshAccessTokenIfNeeded(completion: @escaping (Bool) -> Void) {
        if !accessToken.isEmpty && Date().timeIntervalSince1970 < (tokenExpiry - 300) {
            completion(true)
            return
        }
        
        guard !refreshToken.isEmpty else {
            completion(false)
            return
        }
        
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            self.handleTokenResponse(data: data, error: error, completion: completion)
        }.resume()
    }
    
    private func handleTokenResponse(data: Data?, error: Error?, completion: @escaping (Bool) -> Void) {
        guard let data = data, error == nil else {
            completion(false)
            return
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let access = json["access_token"] as? String {
            
            DispatchQueue.main.async {
                self.accessToken = access
                if let refresh = json["refresh_token"] as? String {
                    self.refreshToken = refresh
                }
                if let expires = json["expires_in"] as? Int {
                    self.tokenExpiry = Date().timeIntervalSince1970 + Double(expires)
                }
                self.isAuthenticated = true
                completion(true)
                self.fetchPlaylists()
            }
        } else {
            completion(false)
        }
    }
    
    func fetchPlaylists() {
        refreshAccessTokenIfNeeded { success in
            guard success else {
                print("YT Auth: Failed to refresh access token before fetching playlists.")
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&maxResults=20")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("YT FetchPlaylists Error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("YT FetchPlaylists Status Code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("YT FetchPlaylists: No data returned.")
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("YT FetchPlaylists JSON Response: \(jsonString)")
                }
                
                guard let responseObj = try? JSONDecoder().decode(YTPlaylistResponse.self, from: data) else {
                    print("YT FetchPlaylists: Failed to decode JSON into YTPlaylistResponse.")
                    return
                }
                
                DispatchQueue.main.async {
                    self.playlists = responseObj.items
                    if let first = responseObj.items.first {
                        self.fetchPlaylistItems(playlistId: first.id)
                    } else {
                        print("YT FetchPlaylists: No playlists found.")
                    }
                }
            }.resume()
        }
    }
    
    func fetchPlaylistItems(playlistId: String) {
        refreshAccessTokenIfNeeded { success in
            guard success else {
                print("YT Auth: Failed to refresh access token before fetching playlist items.")
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=\(playlistId)&maxResults=50")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("YT FetchPlaylistItems Error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("YT FetchPlaylistItems Status Code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("YT FetchPlaylistItems: No data returned.")
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("YT FetchPlaylistItems JSON Response: \(jsonString)")
                }
                
                guard let responseObj = try? JSONDecoder().decode(YTPlaylistItemsResponse.self, from: data) else {
                    print("YT FetchPlaylistItems: Failed to decode JSON into YTPlaylistItemsResponse.")
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentPlaylistTracks = responseObj.items.enumerated().map { (index, track) in
                        YTQueueItem(
                            id: "\(index)-\(track.snippet.resourceId.videoId)",
                            title: track.snippet.title,
                            artist: track.snippet.videoOwnerChannelTitle ?? "Unknown Artist",
                            imageURL: track.snippet.thumbnails?.medium?.url ?? track.snippet.thumbnails?.default?.url,
                            videoId: track.snippet.resourceId.videoId,
                            playlistId: playlistId
                        )
                    }
                    print("YT FetchPlaylistItems: Successfully fetched \(self.currentPlaylistTracks.count) tracks.")
                }
            }.resume()
        }
    }
    
    func playPlaylist(playlistId: String) {
        if let url = URL(string: "https://music.youtube.com/playlist?list=\(playlistId)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func play(videoId: String, playlistId: String? = nil, index: Int = 0) {
        var urlString = "https://music.youtube.com/watch?v=\(videoId)"
        
        if let pid = playlistId {
            urlString += "&list=\(pid)&index=\(index + 1)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
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

extension YouTubeMusicManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSWindow()
    }
}
