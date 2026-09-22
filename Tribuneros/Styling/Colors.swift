//
//  Colors.swift
//  Tribuneros
//
//  Created by albert vila on 22/4/25.
//

import SwiftUI

extension Color {

    static func tribuneru(_ palette: Palette) -> Color {
        switch palette {
        case .green(let brightness, let saturation):
            .green(brightness: brightness, saturation: saturation)
        case .greenCardBackground:
            Color.green.opacity(0.2)
        case.greenSoft:
            Color.green.opacity(0.4)
        case .blueMissingInfoBackground:
            Color.blue.opacity(0.2)
        case .black:
            .black
        case .gray:
            .gray
        case .white(let level):
            Color(white: level)
        case .vaporPageBackground:
            Color(hex: 0x070A0E)
        case .vaporCardSurface:
            Color(hex: 0x121821)
        case .vaporTextPrimary:
            Color(hex: 0xEAF0F6)
        case .vaporTextSecondary:
            Color(hex: 0x8B97A6)
        case .vaporAccent:
            Color(hex: 0x5EEAD4)
        case .vaporLive:
            Color(hex: 0x4ADE80)
        case .vaporPanelRacing:
            Color(hex: 0x0A1715)
        case .vaporPanelToday:
            Color(hex: 0x08121F)
        case .vaporPanelYesterday:
            Color(hex: 0x0E0F22)
        case .vaporPanelTomorrow:
            Color(hex: 0x150E1E)
        case .vaporPanelLive:
            Color(hex: 0x1A0B10)
        }
    }

    enum Palette {
        case greenCardBackground
        case greenSoft
        case green(brightness: Double = 1.0, saturation: Double = 1.0)
        case blueMissingInfoBackground
        case black
        case gray
        case white(level: Double)

        // MARK: - Vapor (Home "Panel" redesign) -
        case vaporPageBackground
        case vaporCardSurface
        case vaporTextPrimary
        case vaporTextSecondary
        case vaporAccent
        case vaporLive
        case vaporPanelRacing
        case vaporPanelToday
        case vaporPanelYesterday
        case vaporPanelTomorrow
        /// Darker than `vaporCardSurface` (relative luminance 0.0049 vs 0.0093),
        /// keeping the Vapor spec's rule that a panel is always darker than the
        /// cards on it. See `agent-doc/home_redesign_spec.md` §1 and §8 (the
        /// section→colour mapping is a free choice).
        case vaporPanelLive
    }
}

extension Color {
    /// - Parameters:
    ///   - hex: an RGB value, e.g. `0x121821`.
    ///   - opacity: 0...1, defaults to fully opaque.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Color {
    static func green(brightness: Double = 1.0, saturation: Double = 1.0) -> Color {
        let clampedBrightness = min(max(brightness, 0), 1)
        let clampedSaturation = min(max(saturation, 0), 1)
        return Color(hue: 0.33, saturation: clampedSaturation, brightness: clampedBrightness)
    }
}
