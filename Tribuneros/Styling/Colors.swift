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
        case .vaporProfileFuture:
            Color(hex: 0x9ACD32)
        case .vaporProfileDone:
            Color(hex: 0xE6F2D9)
        case .vaporGroupBadge:
            Color(hex: 0x2F6FDE)
        case .mudPageBackground:
            Color(hex: 0x0E0B08)
        case .mudCardSurface:
            Color(hex: 0x1C1612)
        case .mudRaised:
            Color(hex: 0x261E18)
        case .mudTrack:
            Color(hex: 0x3A2E24)
        case .mudTextPrimary:
            Color(hex: 0xF3ECE4)
        case .mudTextSecondary:
            Color(hex: 0xA8998A)
        case .mudTextMuted:
            Color(hex: 0xC9BBAB)
        case .mudAccent:
            Color(hex: 0xE0A458)
        case .mudTagNeutral:
            Color(hex: 0x3A2E24)
        case .mudTagNeutralText:
            Color(hex: 0xE8DCCD)
        case .mudSkyTop:
            Color(hex: 0x3A2A20)
        case .mudSkyBottom:
            Color(hex: 0x8A5A38)
        case .mudSun:
            Color(hex: 0xF2C48A)
        case .mudHillFar:
            Color(hex: 0x4A3424)
        case .mudHillNear:
            Color(hex: 0x6B4A30)
        case .mudTree:
            Color(hex: 0x2A1E15)
        case .mudTape:
            Color(hex: 0xF3ECE4)
        case .mudPuddle:
            Color(hex: 0x1C140D)
        case .mudGround:
            Color(hex: 0x4A3220)
        case .mudNegative:
            Color(hex: 0xE5766B)
        case .mudLive:
            Color(hex: 0x9CC27A)
        case .cxArtRider:
            Color(hex: 0x120E0C)
        case .cxArtBlue:
            Color(hex: 0x2F6FDE)
        case .cxArtFrost:
            Color(hex: 0xE6E0DA)
        case .cxArtMist:
            Color(hex: 0xD8D2CE)
        case .cxArtSilhouette:
            Color(hex: 0x1E1A18)
        case .cxArtEarth:
            Color(hex: 0x8A6A48)
        case .cxArtShadow:
            Color(hex: 0x2A1E1A)
        case .cxDawnSkyTop:
            Color(hex: 0x1E2230)
        case .cxDawnSkyMid:
            Color(hex: 0x5A4A50)
        case .cxDawnSkyBottom:
            Color(hex: 0xC98A5E)
        case .cxDawnHillFar:
            Color(hex: 0x3E3A46)
        case .cxDawnHillNear:
            Color(hex: 0x54485A)
        case .cxDawnGroundTop:
            Color(hex: 0x6A5C58)
        case .cxDawnGroundBottom:
            Color(hex: 0x3A2E2A)
        case .cxRainSkyTop:
            Color(hex: 0x15161C)
        case .cxRainSkyBottom:
            Color(hex: 0x4A3C34)
        case .cxRainCloudDark:
            Color(hex: 0x2A2830)
        case .cxRainCloudLight:
            Color(hex: 0x3A3640)
        case .cxRainHill:
            Color(hex: 0x2E2A2C)
        case .cxRainSlopeTop:
            Color(hex: 0x5A3E28)
        case .cxRainSlopeBottom:
            Color(hex: 0x2E2014)
        case .cxRainDrop:
            Color(hex: 0xC9C4C0)
        case .cxCoastSkyTop:
            Color(hex: 0x2C3440)
        case .cxCoastSkyBottom:
            Color(hex: 0x9A8C80)
        case .cxCoastSeaTop:
            Color(hex: 0x4A5A62)
        case .cxCoastSeaBottom:
            Color(hex: 0x2E3A40)
        case .cxCoastFoam:
            Color(hex: 0xD8CCBC)
        case .cxCoastDuneTop:
            Color(hex: 0xB08A5E)
        case .cxCoastDuneBottom:
            Color(hex: 0x6E5236)
        case .cxCoastGrass:
            Color(hex: 0x4A5A3A)
        case .cxCoastTrack:
            Color(hex: 0x5A4028)
        case .cxTentSkyTop:
            Color(hex: 0x1E1820)
        case .cxTentSkyBottom:
            Color(hex: 0x7A4A34)
        case .cxTentHill:
            Color(hex: 0x2E221C)
        case .cxTentTree:
            Color(hex: 0x1C140F)
        case .cxTentFan:
            Color(hex: 0x3A2A24)
        case .cxTentRut:
            Color(hex: 0x2E1E12)
        case .cxFloodSkyTop:
            Color(hex: 0x0B0A10)
        case .cxFloodSkyBottom:
            Color(hex: 0x2A2230)
        case .cxFloodLight:
            Color(hex: 0xF2E6C8)
        case .cxFloodMast:
            Color(hex: 0x1A161C)
        case .cxFloodHill:
            Color(hex: 0x2E2830)
        case .cxFloodSnowTop:
            Color(hex: 0xC8C2C4)
        case .cxFloodSnowBottom:
            Color(hex: 0x5A5058)
        case .cxFloodArch:
            Color(hex: 0x1E1A20)
        case .cxForestSkyTop:
            Color(hex: 0x3A3430)
        case .cxForestSkyBottom:
            Color(hex: 0x7A6A5A)
        case .cxForestTreeFar:
            Color(hex: 0x5A4C42)
        case .cxForestBank:
            Color(hex: 0x3A2A1C)
        case .cxForestMudBottom:
            Color(hex: 0x22160C)
        case .cxForestFan:
            Color(hex: 0x1E1612)
        case .kitPageBackground:
            Color(hex: 0x0D0B14)
        case .kitCardSurface:
            Color(hex: 0x19152A)
        case .kitSegmentTrack:
            Color(hex: 0x161226)
        case .kitSegmentSelected:
            Color(hex: 0x2E2650)
        case .kitAvatar:
            Color(hex: 0x241E3A)
        case .kitRail:
            Color(hex: 0x2A2440)
        case .kitTextPrimary:
            Color(hex: 0xF0EDF8)
        case .kitTextSecondary:
            Color(hex: 0xA29BB8)
        case .kitTextMuted:
            Color(hex: 0xC8C1DB)
        case .kitAvatarText:
            Color(hex: 0xE3DCFA)
        case .kitAccent:
            Color(hex: 0xBBA9FF)
        case .kitProgram:
            Color(hex: 0x7DD3FC)
        case .kitAdded:
            Color(hex: 0x86EFAC)
        case .kitDropped:
            Color(hex: 0xFDA4AF)
        case .kitSkyTop:
            Color(hex: 0x2A2150)
        case .kitSkyBottom:
            Color(hex: 0x4B3A7A)
        case .kitConfettiYellow:
            Color(hex: 0xF2D04B)
        case .kitConfettiPink:
            Color(hex: 0xF9A8D4)
        // MARK: - Tifosi (Maglia rosa) -
        case .tifosiPageBackground:
            Color(hex: 0x0D090C)
        case .tifosiPanel:
            Color(hex: 0x180E15)
        case .tifosiCard:
            Color(hex: 0x24171F)
        case .tifosiTag:
            Color(hex: 0x3D2636)
        case .tifosiTagText:
            Color(hex: 0xF3D9EA)
        case .tifosiTextPrimary:
            Color(hex: 0xF6ECF2)
        case .tifosiTextSecondary:
            Color(hex: 0xB39CAA)
        case .tifosiTextMuted:
            Color(hex: 0xD6C0CD)
        case .tifosiAccent:
            Color(hex: 0xF9A8D4)
        case .tifosiOnAccent:
            Color(hex: 0x2B0A1C)
        case .tifosiLine:
            Color(hex: 0x2E1D28)
        case .tifosiBroomStrip:
            Color(hex: 0x150C12)
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
        case .monumentSkin:
            Color(hex: 0xFF9EC4)
        case .monumentFaceBar:
            Color(hex: 0x0B0B0B)
        case .monumentInk:
            Color(hex: 0x111111)
        case .monumentOrange:
            Color(hex: 0xFF7A1A)
        case .monumentYellow:
            Color(hex: 0xFFD60A)
        case .monumentRed:
            Color(hex: 0xFF1F4B)
        case .monumentBlue:
            Color(hex: 0x1E6FFF)
        case .monumentWhite:
            Color(hex: 0xFFFFFF)
        case .monumentSlate:
            Color(hex: 0x4B5563)
        case .monumentPaveLight:
            Color(hex: 0xC9CED6)
        case .monumentPaveDark:
            Color(hex: 0xAEB5C0)
        case .monumentTrophy:
            Color(hex: 0xB8BEC8)
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
        /// The profile's bright green: the part still to ride.
        case vaporProfileFuture
        /// The profile's pale yellow-green: the part already ridden.
        case vaporProfileDone
        /// The blue round badge of a group in the situation list.
        case vaporGroupBadge
        // MARK: - Mud (CX Zone Series lens) -
        case mudPageBackground
        case mudCardSurface
        case mudRaised
        case mudTrack
        case mudTextPrimary
        case mudTextSecondary
        case mudTextMuted
        case mudAccent
        case mudTagNeutral
        case mudTagNeutralText
        case mudSkyTop
        case mudSkyBottom
        case mudSun
        case mudHillFar
        case mudHillNear
        case mudTree
        case mudTape
        case mudPuddle
        case mudGround
        case mudNegative
        case mudLive
        // MARK: - CX series paintings (CX Zone next-round hero) -
        case cxArtRider
        case cxArtBlue
        case cxArtFrost
        case cxArtMist
        case cxArtSilhouette
        case cxArtEarth
        case cxArtShadow
        case cxDawnSkyTop
        case cxDawnSkyMid
        case cxDawnSkyBottom
        case cxDawnHillFar
        case cxDawnHillNear
        case cxDawnGroundTop
        case cxDawnGroundBottom
        case cxRainSkyTop
        case cxRainSkyBottom
        case cxRainCloudDark
        case cxRainCloudLight
        case cxRainHill
        case cxRainSlopeTop
        case cxRainSlopeBottom
        case cxRainDrop
        case cxCoastSkyTop
        case cxCoastSkyBottom
        case cxCoastSeaTop
        case cxCoastSeaBottom
        case cxCoastFoam
        case cxCoastDuneTop
        case cxCoastDuneBottom
        case cxCoastGrass
        case cxCoastTrack
        case cxTentSkyTop
        case cxTentSkyBottom
        case cxTentHill
        case cxTentTree
        case cxTentFan
        case cxTentRut
        case cxFloodSkyTop
        case cxFloodSkyBottom
        case cxFloodLight
        case cxFloodMast
        case cxFloodHill
        case cxFloodSnowTop
        case cxFloodSnowBottom
        case cxFloodArch
        case cxForestSkyTop
        case cxForestSkyBottom
        case cxForestTreeFar
        case cxForestBank
        case cxForestMudBottom
        case cxForestFan
        // MARK: - Kit (Paddock timeline) -
        case kitPageBackground
        case kitCardSurface
        case kitSegmentTrack
        case kitSegmentSelected
        case kitAvatar
        case kitRail
        case kitTextPrimary
        case kitTextSecondary
        case kitTextMuted
        case kitAvatarText
        case kitAccent
        case kitProgram
        case kitAdded
        case kitDropped
        case kitSkyTop
        case kitSkyBottom
        case kitConfettiYellow
        case kitConfettiPink
        // MARK: - Tifosi -
        case tifosiPageBackground
        case tifosiPanel
        case tifosiCard
        case tifosiTag
        case tifosiTagText
        case tifosiTextPrimary
        case tifosiTextSecondary
        case tifosiTextMuted
        case tifosiAccent
        case tifosiOnAccent
        case tifosiLine
        case tifosiBroomStrip
        /// The world champion jersey's bands, as drawn in the spoiler paintings.
        case championBlue
        case championRed
        case championBlack
        case championYellow
        case championGreen
        /// The Monuments triple-champion paintings (Results yesterday spoiler covers).
        case monumentSkin
        case monumentFaceBar
        case monumentInk
        case monumentOrange
        case monumentYellow
        case monumentRed
        case monumentBlue
        case monumentWhite
        case monumentSlate
        case monumentPaveLight
        case monumentPaveDark
        case monumentTrophy
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
