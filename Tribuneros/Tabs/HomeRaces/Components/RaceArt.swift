//
//  RaceArt.swift
//  Tribuneros
//

import SwiftUI

enum RaceArt {
    case day
    case night
    case banner
    case spoiler
    case emptyPodium

    var assetName: String {
        switch self {
        case .day: "RaceArtDay"
        case .night: "RaceArtNight"
        case .banner: "RaceArtBanner"
        case .spoiler: "SpoilerArt"
        case .emptyPodium: "EmptyPodiumArt"
        }
    }
}

struct RaceArtView: View {
    let art: RaceArt
    var alignment: Alignment = .center

    var body: some View {
        Color.clear
            .overlay(alignment: alignment) {
                Image(art.assetName)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

extension RaceArtView {
    static var fallback: RaceArtView {
        RaceArtView(art: .day, alignment: .trailing)
    }
}
