import SwiftUI

enum PluginCategory: String, CaseIterable, Codable {
    case media = "Media & Music"
    case productivity = "Productivity"
    case system = "System Utilities"
}

struct WaveNotchPlugin: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let iconName: String // SFSymbol fallback
    let assetImageName: String? // Real asset name
    let category: PluginCategory
    let storageKeyBase: String // Used for @AppStorage
    
    var installedKey: String { "\(storageKeyBase)_installed" }
    var enabledKey: String { "\(storageKeyBase)_enabled" }
}
