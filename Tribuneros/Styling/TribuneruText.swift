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
        case .vaporScreenDate, .vaporMeta, .vaporFeedDetail:
            "SpaceGrotesk-Regular"
        case .vaporRaceNameNext, .vaporRaceNameResult, .vaporWinnerName, .vaporTabLabel, .vaporPressName:
            "SpaceGrotesk-SemiBold"
        case .vaporSpoilerChip, .vaporFeedTag, .vaporChangeSign, .vaporAge:
            "SpaceMono-Bold"
        case .vaporFinishTime, .vaporETALine, .vaporMonoMeta, .vaporGroupLabel:
            "SpaceMono-Regular"
        case .vaporHeading, .vaporHeroTitle, .vaporTag, .vaporTagSmall, .vaporResultTitle, .vaporBannerTitle, .vaporSeeAll:
            "SpaceGrotesk-Bold"
        case .vaporHeroSubtitle:
            "SpaceGrotesk-Medium"
        case .vaporLink, .vaporRowTitle, .vaporRowCountdown:
            "SpaceGrotesk-SemiBold"
        case .vaporRowMeta, .vaporBannerSubtitle:
            "SpaceGrotesk-Regular"
        case .vaporPill, .vaporStatTime, .vaporRowTime, .vaporResultTime:
            "SpaceMono-Bold"
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
        case .vaporRaceNameResult: 13
        case .vaporFinishTime: 12
        case .vaporETALine: 11
        case .vaporMeta: 11
        case .vaporTabLabel: 11
        case .vaporPressName: 13
        case .vaporFeedDetail: 12
        case .vaporFeedTag: 10
        case .vaporMonoMeta, .vaporGroupLabel: 11
        case .vaporChangeSign: 12
        case .vaporAge: 14
        case .vaporHeading: 22
        case .vaporHeroTitle: 26
        case .vaporHeroSubtitle: 13
        case .vaporTag: 12
        case .vaporTagSmall: 11
        case .vaporPill: 13
        case .vaporStatTime: 15
        case .vaporLink, .vaporSeeAll: 14
        case .vaporRowTitle: 16
        case .vaporRowMeta: 12
        case .vaporRowCountdown: 12
        case .vaporRowTime: 18
        case .vaporResultTitle: 15
        case .vaporResultTime: 12
        case .vaporBannerTitle: 18
        case .vaporBannerSubtitle: 13
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
             .vaporFeedTag, .vaporChangeSign, .vaporAge,
             .vaporHeading, .vaporHeroTitle, .vaporTag, .vaporTagSmall, .vaporPill, .vaporStatTime,
             .vaporRowTime, .vaporResultTitle, .vaporResultTime, .vaporBannerTitle, .vaporSeeAll:
            .bold
        case .vaporRaceNameNext, .vaporRaceNameResult, .vaporWinnerName, .vaporTabLabel, .vaporPressName,
             .vaporLink, .vaporRowTitle, .vaporRowCountdown:
            .semibold
        case .vaporHeroSubtitle:
            .medium
        case .vaporScreenDate, .vaporMeta, .vaporFinishTime, .vaporETALine,
             .vaporFeedDetail, .vaporMonoMeta, .vaporGroupLabel,
             .vaporRowMeta, .vaporBannerSubtitle:
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
        case .vaporFeedTag: 0.8
        case .vaporGroupLabel: 0.66
        case .vaporHeading: -0.4
        case .vaporHeroTitle: -0.6
        case .vaporTag: 0.9
        case .vaporTagSmall: 0.7
        default: 0
        }
    }
    /// Space Mono is monospaced by construction; this also asks the system
    /// font (if ever substituted) to keep digits tabular.
    private var isTabularNumeric: Bool {
        switch style {
        case .vaporFinishTime, .vaporETALine,
             .vaporMonoMeta, .vaporAge, .vaporPill, .vaporStatTime, .vaporRowTime, .vaporResultTime,
             .vaporRowCountdown:
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
        case vaporWinnerName
        case vaporFinishTime
        case vaporETALine
        case vaporMeta
        case vaporTabLabel

        // MARK: - Vapor (Paddock) -
        case vaporPressName
        case vaporFeedDetail
        case vaporFeedTag
        case vaporMonoMeta
        case vaporGroupLabel
        case vaporChangeSign
        case vaporAge

        // MARK: - Vapor (Today races redesign) -
        case vaporHeading
        case vaporLink
        case vaporHeroTitle
        case vaporHeroSubtitle
        case vaporTag
        case vaporTagSmall
        case vaporPill
        case vaporStatTime
        case vaporRowTitle
        case vaporRowMeta
        case vaporRowCountdown
        case vaporRowTime
        case vaporResultTitle
        case vaporResultTime
        case vaporBannerTitle
        case vaporBannerSubtitle
        case vaporSeeAll
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
