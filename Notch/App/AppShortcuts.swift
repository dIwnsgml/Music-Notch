import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    // ⚡️ GLOBAL VISIBILITY
    static let toggleAppVisibility = Self("toggleAppVisibility", default: .init(.h, modifiers: [.control, .command]))
    
    // ⚡️ TOGGLES
    static let toggleLiveLyrics = Self("toggleLiveLyrics", default: .init(.l, modifiers: [.control, .command]))
    static let toggleBannerLyrics = Self("toggleBannerLyrics", default: .init(.m, modifiers: [.control, .command]))
    static let toggleBanner = Self("toggleBanner", default: .init(.a, modifiers: [.control, .command]))
    
    // ⚡️ LYRIC SYNCHRONIZATION
    static let increaseOffset = Self("increaseOffset", default: .init(.equal, modifiers: [.control, .command]))
    static let decreaseOffset = Self("decreaseOffset", default: .init(.minus, modifiers: [.control, .command]))
    
    // ⚡️ UI ADJUSTMENTS (Lines)
    static let increaseLines = Self("increaseLines", default: .init(.p, modifiers: [.control, .command]))
    static let decreaseLines = Self("decreaseLines", default: .init(.b, modifiers: [.control, .command]))
    
    // ⚡️ UI ADJUSTMENTS (Hover Delay) - Changed to Brackets [ and ]
    static let increaseDelay = Self("increaseDelay", default: .init(.rightBracket, modifiers: [.control, .command]))
    static let decreaseDelay = Self("decreaseDelay", default: .init(.leftBracket, modifiers: [.control, .command]))
}
