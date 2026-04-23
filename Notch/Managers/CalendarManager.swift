import Foundation
import EventKit
import Combine
import AppKit

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    private let store = EKEventStore()
    
    @Published var hasAccess = false
    @Published var todaysEvents: [EKEvent] = []
    
    private var timer: Timer?
    
    init() {
        checkAccessStatus()
        
        // ⚡️ PERIODIC REFRESH: Every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.fetchTodaysEvents()
        }
    }
    
    func checkAccessStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        DispatchQueue.main.async {
            // Check for both legacy authorized and modern fullAccess
            if #available(macOS 14.0, *) {
                self.hasAccess = (status == .fullAccess)
            } else {
                self.hasAccess = (status == .authorized)
            }
            
            if self.hasAccess {
                self.fetchTodaysEvents()
            }
        }
    }
    
    func requestAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        // If macOS already denied it, jump straight to System Settings!
        if status == .denied || status == .restricted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        // ⚡️ THE FIX: Rolled back to standard EventKit access request
        store.requestAccess(to: .event) { granted, error in
            if let error = error {
                print("⚠️ WaveNotch Calendar Error: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                self.hasAccess = granted
                if granted { self.fetchTodaysEvents() }
            }
        }
    }
    
    func fetchTodaysEvents() {
        guard hasAccess else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
        
        DispatchQueue.main.async {
            // Sort by start time and filter out events that have already ended
            self.todaysEvents = events
                .filter { $0.endDate > now }
                .sorted { $0.startDate < $1.startDate }
        }
    }
}
