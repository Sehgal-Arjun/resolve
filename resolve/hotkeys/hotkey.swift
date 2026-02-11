import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePalette = Self("togglePalette")
    static let closeInstance = Self("closeInstance")
    static let diveIn = Self("diveIn")
}

let diveInNotification = NSNotification.Name("resolve.diveIn")
