//
//  TribuneruText.swift
//  Tribuneros
//
//  Created by albert vila on 28/4/25.
//

import SwiftUI

struct TribuneruText: View {
    let content: String
    let color: Color
    let lineLimit: Int
    let style: Style

    init(content: String, style: Style, color: Color = .white, lineLimit: Int = 1) {
        self.content = content
        self.color = color
        self.lineLimit = lineLimit
        self.style = style
    }

    var body: some View {
        let text = Text(content)
            .lineLimit(lineLimit)
            .font(resolvedFont)
            .tracking(tracking)
            .foregroundColor(color)
        if isTabularNumeric {
            text.monospacedDigit()
        } else {
            text
        }
    }

    /// Fixed point size — matches the app's existing `.system(size:...)` usage,
    /// which does not scale with Dynamic Type.
    private var resolvedFont: Font {
        if let fontName {
            return .custom(fontName, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: design)
    }

    /// The bundled PostScript name to use, or `nil` to fall back to the system font.
    /// See `Fonts/` and `Info.plist`'s `UIAppFonts` for the six installed weights.
    private var fontName: String? {
        switch style {
        case .size20WeightBold, .size16WeightBold, .size16WeightSemiBold,
             .size14WeightSemiBold, .size14WeightRegular, .size14LightMonospaced,
             .size12WeightRegular, .size10WeightRegular:
            nil
        case .vaporScreenTitle, .vaporSectionTitle:
            "SpaceGrotesk-Bold"
        case .vaporScreenDate, .vaporMeta:
            "SpaceGrotesk-Regular"
        case .vaporRaceNameTomorrow:
            "SpaceGrotesk-Medium"
        case .vaporRaceNameNext, .vaporRaceNameResult, .vaporWinnerName, .vaporCountdown, .vaporTabLabel, .vaporListTitle:
            "SpaceGrotesk-SemiBold"
        case .vaporSpoilerChip:
            "SpaceMono-Bold"
        case .vaporETANext, .vaporStartTimeTomorrow:
            "SpaceMono-Bold"
        case .vaporFinishTime, .vaporETALine:
            "SpaceMono-Regular"
        }
    }

    private var size: CGFloat {
        switch style {
        case .size20WeightBold: 20
        case .size16WeightBold, .size16WeightSemiBold: 16
        case .size14WeightSemiBold: 14
        case .size14WeightRegular: 14
        case .size14LightMonospaced: 14
        case .size12WeightRegular: 12
        case .size10WeightRegular: 10
        case .vaporScreenTitle: 24
        case .vaporScreenDate: 12
        case .vaporSectionTitle: 30
        case .vaporSpoilerChip: 11
        case .vaporRaceNameNext, .vaporWinnerName: 14
        case .vaporRaceNameResult, .vaporRaceNameTomorrow: 13
        case .vaporETANext: 20
        case .vaporStartTimeTomorrow: 18
        case .vaporFinishTime: 12
        case .vaporETALine: 11
        case .vaporCountdown: 11
        case .vaporMeta: 11
        case .vaporTabLabel: 11
        case .vaporListTitle: 18
        }
    }
    private var weight: Font.Weight {
        switch style {
        case .size20WeightBold: .bold
        case .size16WeightBold: .bold
        case .size16WeightSemiBold: .semibold
        case .size14WeightSemiBold: .semibold
        case .size14WeightRegular: .regular
        case .size14LightMonospaced: .light
        case .size12WeightRegular: .regular
        case .size10WeightRegular: .regular
        // Weight for the vapor cases is baked into the loaded font file
        // (see `fontName`); this value is unused but kept exhaustive.
        case .vaporScreenTitle, .vaporSectionTitle, .vaporSpoilerChip,
             .vaporETANext, .vaporStartTimeTomorrow:
            .bold
        case .vaporRaceNameNext, .vaporRaceNameResult, .vaporWinnerName, .vaporCountdown, .vaporTabLabel, .vaporListTitle:
            .semibold
        case .vaporRaceNameTomorrow:
            .medium
        case .vaporScreenDate, .vaporMeta, .vaporFinishTime, .vaporETALine:
            .regular
        }
    }
    private var design: Font.Design {
        switch style {
        case .size14LightMonospaced: .monospaced
        default: .default
        }
    }
    private var tracking: CGFloat {
        switch style {
        case .vaporScreenTitle: -0.4
        case .vaporSectionTitle: -0.8
        case .vaporETANext: -0.5
        case .vaporStartTimeTomorrow: -0.4
        default: 0
        }
    }
    /// Space Mono is monospaced by construction; this also asks the system
    /// font (if ever substituted) to keep digits tabular.
    private var isTabularNumeric: Bool {
        switch style {
        case .vaporETANext, .vaporStartTimeTomorrow, .vaporFinishTime, .vaporETALine:
            true
        default:
            false
        }
    }
}

extension TribuneruText {
    enum Style {
        case size20WeightBold
        case size16WeightBold
        case size16WeightSemiBold
        case size14WeightSemiBold
        case size14WeightRegular
        case size14LightMonospaced
        case size12WeightRegular
        case size10WeightRegular

        // MARK: - Vapor (Home "Panel" redesign) -
        // Space Grotesk / Space Mono. See `agent-doc/home_redesign_spec.md` §2.
        case vaporScreenTitle
        case vaporScreenDate
        case vaporSectionTitle
        case vaporSpoilerChip
        case vaporRaceNameNext
        case vaporRaceNameResult
        case vaporRaceNameTomorrow
        case vaporWinnerName
        case vaporETANext
        case vaporStartTimeTomorrow
        case vaporFinishTime
        case vaporETALine
        case vaporCountdown
        case vaporMeta
        case vaporTabLabel
        /// A list row's title — Hate Zone's link rows. Not part of the
        /// original Home ramp, added when Vapor rolled out to other tabs.
        case vaporListTitle
    }
}

// MARK: - Helpers -

enum TribuneruTextStyle {
    case size20WeightBold
    case size16WeightBold
    case size16WeightSemiBold
    case size14WeightSemiBold
    case size14WeightRegular
    case size14LightMonospaced
    case size12WeightRegular
    case size10WeightRegular
    
    var size: CGFloat {
        switch self {
        case .size20WeightBold: return 20
        case .size16WeightBold, .size16WeightSemiBold: return 16
        case .size14WeightSemiBold, .size14WeightRegular, .size14LightMonospaced: return 14
        case .size12WeightRegular: return 12
        case .size10WeightRegular: return 10
        }
    }
    
    var weight: Font.Weight {
        switch self {
        case .size20WeightBold, .size16WeightBold: return .bold
        case .size16WeightSemiBold, .size14WeightSemiBold: return .semibold
        case .size14WeightRegular, .size12WeightRegular, .size10WeightRegular: return .regular
        case .size14LightMonospaced: return .light
        }
    }
    
    var design: Font.Design {
        switch self {
        case .size14LightMonospaced: return .monospaced
        default: return .default
        }
    }
}
struct TribuneruTextModifier: ViewModifier {
    let style: TribuneruTextStyle
    let color: Color
    let lineLimit: Int
    
    func body(content: Content) -> some View {
        content
            .lineLimit(lineLimit)
            .font(.system(size: style.size, weight: style.weight, design: style.design))
            .foregroundColor(color)
    }
}

extension View {
    func tribuneruStyle(_ style: TribuneruTextStyle, color: Color = .white, lineLimit: Int = 1) -> some View {
        modifier(TribuneruTextModifier(style: style, color: color, lineLimit: lineLimit))
    }
}
