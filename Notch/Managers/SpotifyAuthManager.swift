import AuthenticationServices
import SwiftUI
import Combine
import CryptoKit

class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()
    
    @AppStorage("spotifyAccessToken") var accessToken: String = ""
    @AppStorage("spotifyRefreshToken") var refreshToken: String = ""
    
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
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    if let access = json["access_token"] as? String {
                        self.accessToken = access
                    }
                    if let refresh = json["refresh_token"] as? String {
                        self.refreshToken = refresh
                    }
                }
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
