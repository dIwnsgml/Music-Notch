import SwiftUI
import AuthenticationServices
import Combine
import CryptoKit

class GoogleCalendarManager: NSObject, ObservableObject {
    static let shared = GoogleCalendarManager()
    
    @AppStorage("google_access_token") var accessToken: String = ""
    @AppStorage("google_refresh_token") var refreshToken: String = ""
    @AppStorage("google_token_expiry") var tokenExpiry: Double = 0
    
    @Published var upcomingEvents: [GoogleCalendarEvent] = []
    @Published var isFetching = false
    @Published var isAuthenticated = false
    
    private let clientID = "989490326013-4ukfahi6t9cplb3mujovrrbtb1onoif0.apps.googleusercontent.com"
    private let scopes = "https://www.googleapis.com/auth/calendar.readonly"
    
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String = ""
    private var timer: Timer?
    
    override init() {
        super.init()
        self.isAuthenticated = !accessToken.isEmpty
        
        // Periodic refresh every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.fetchTodaysEvents()
        }
        
        if isAuthenticated {
            fetchTodaysEvents()
        }
        
        // ⚡️ URL Callback Listener
        NotificationCenter.default.addObserver(forName: NSNotification.Name("GoogleAuthCallback"), object: nil, queue: .main) { notification in
            if let code = notification.object as? String {
                self.exchangeCodeForToken(code: code) { _ in }
            }
        }
    }
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        // 1. Generate PKCE
        self.codeVerifier = generateRandomString(length: 64)
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // 2. Google's required scheme for native apps is reversed client ID
        let reversedID = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirectURI = "\(reversedID):/google-callback"
        
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
        
        // 3. Callback scheme is just the reversed ID
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: reversedID) { callbackURL, error in
            if let error = error {
                print("Google Auth Error: \(error.localizedDescription)")
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
        
        let reversedID = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirectURI = "\(reversedID):/google-callback"
        
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
        guard !refreshToken.isEmpty else {
            completion(false)
            return
        }
        
        if Date().timeIntervalSince1970 < (tokenExpiry - 300) {
            completion(true)
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
            }
        } else {
            completion(false)
        }
    }
    
    func fetchTodaysEvents() {
        refreshAccessTokenIfNeeded { success in
            guard success else { return }
            
            DispatchQueue.main.async { self.isFetching = true }
            
            let listUrl = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
            var listRequest = URLRequest(url: listUrl)
            listRequest.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: listRequest) { data, _, _ in
                guard let data = data,
                      let response = try? JSONDecoder().decode(GoogleCalendarListResponse.self, from: data) else {
                    DispatchQueue.main.async { self.isFetching = false }
                    return
                }
                
                let group = DispatchGroup()
                var allEvents: [GoogleCalendarEvent] = []
                
                let calendar = Calendar.current
                let now = Date()
                let startOfDay = calendar.startOfDay(for: now)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let isoFormatter = ISO8601DateFormatter()
                let timeMin = isoFormatter.string(from: startOfDay)
                let timeMax = isoFormatter.string(from: endOfDay)
                
                for googleCalendar in response.items {
                    group.enter()
                    let eventsUrlString = "https://www.googleapis.com/calendar/v3/calendars/\(googleCalendar.id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"
                    
                    var eventsRequest = URLRequest(url: URL(string: eventsUrlString)!)
                    eventsRequest.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
                    
                    URLSession.shared.dataTask(with: eventsRequest) { eData, _, _ in
                        defer { group.leave() }
                        guard let eData = eData,
                              let eResponse = try? JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: eData) else {
                            return
                        }
                        
                        let mappedEvents = eResponse.items.map { event -> GoogleCalendarEvent in
                            return GoogleCalendarEvent(
                                id: event.id,
                                summary: event.summary,
                                description: event.description,
                                start: event.start,
                                end: event.end,
                                htmlLink: event.htmlLink,
                                calendarId: googleCalendar.id,
                                calendarColor: googleCalendar.backgroundColor
                            )
                        }
                        
                        allEvents.append(contentsOf: mappedEvents)
                    }.resume()
                }
                
                group.notify(queue: .main) {
                    self.upcomingEvents = allEvents
                        .filter { event in
                            if let endStr = event.end.dateTime ?? event.end.date,
                               let endDate = self.parseGoogleDate(endStr) {
                                return endDate > now
                            }
                            return true
                        }
                        .sorted { e1, e2 in
                            let d1 = e1.start.dateTime ?? e1.start.date ?? ""
                            let d2 = e2.start.dateTime ?? e2.start.date ?? ""
                            return d1 < d2
                        }
                    self.isFetching = false
                }
            }.resume()
        }
    }
    
    private func parseGoogleDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: str) { return date }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        return dayFormatter.date(from: str)
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

extension GoogleCalendarManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSWindow()
    }
}
