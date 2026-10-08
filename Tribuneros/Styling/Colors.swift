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
        case .vaporNegative:
            Color(hex: 0xFB7185)
        case .vaporLiveRed:
            Color(hex: 0xE11D48)
        case .vaporTagNeutral:
            Color(hex: 0x263049)
        case .vaporTagNeutralText:
            Color(hex: 0xD3DCE8)
        case .vaporTextMuted:
            Color(hex: 0xB7C2CF)
        case .championBlue:
            Color(hex: 0x2563EB)
        case .championRed:
            Color(hex: 0xE11D48)
        case .championBlack:
            Color(hex: 0x111111)
        case .championYellow:
            Color(hex: 0xFACC15)
        case .championGreen:
            Color(hex: 0x16A34A)
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
        case vaporNegative
        /// The LIVE tag; red on purpose, unlike the green `vaporLive` dot.
        case vaporLiveRed
        case vaporTagNeutral
        case vaporTagNeutralText
        case vaporTextMuted
        /// The world champion jersey's bands, as drawn in the spoiler paintings.
        case championBlue
        case championRed
        case championBlack
        case championYellow
        case championGreen
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
