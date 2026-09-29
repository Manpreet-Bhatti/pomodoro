import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    /// Light/dark pair; each value meets WCAG AA against its window background.
    init(light: UInt32, dark: UInt32) {
        self.init(
            nsColor: NSColor(name: nil) {
                NSColor(Color(hex: $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light))
            })
    }

    // ponytail: no Increase Contrast variants, add bestMatch cases if Accessibility Inspector flags them
    static let sakura = Color(light: 0xC2305E, dark: 0xFFB7C5)  // primary
    static let bark = Color(light: 0x8B5A2B, dark: 0xD9A673)  // secondary
}
