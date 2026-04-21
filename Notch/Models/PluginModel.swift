import SwiftUI

enum PluginCategory: String, CaseIterable {
    case media = "Media & Music"
    case productivity = "Productivity"
    case system = "System Utilities"
}

struct WaveNotchPlugin: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let assetImageName: String 
    let category: PluginCategory
    let isPremium: Bool
    let storageKey: String 
    
    var installedKey: String { "\(storageKey)_installed" }
    var enabledKey: String { "\(storageKey)_enabled" }
}