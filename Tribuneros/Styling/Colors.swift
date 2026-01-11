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
    }
}

extension Color {
    static func green(brightness: Double = 1.0, saturation: Double = 1.0) -> Color {
        let clampedBrightness = min(max(brightness, 0), 1)
        let clampedSaturation = min(max(saturation, 0), 1)
        return Color(hue: 0.33, saturation: clampedSaturation, brightness: clampedBrightness)
    }
}
