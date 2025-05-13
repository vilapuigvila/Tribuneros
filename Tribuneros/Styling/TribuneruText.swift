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
        Text(content)
            .lineLimit(lineLimit)
            .font(.system(size: size, weight: weight, design: design))
            .foregroundColor(color)
    }
    
    private var size: CGFloat {
        switch style {
        case .size20WeightBold: 20
        case .size16WeightBold, .size16WeightSemiBold: 16
        case .size14WeightSemiBold: 14
        case .size14WeightRegular: 14
        case .size14LightMonospaced: 14
        case .size12WeightRegular: 12
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
        }
    }
    private var design: Font.Design {
        switch style {
        case .size14LightMonospaced: .monospaced
        default: .default
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
    
    var size: CGFloat {
        switch self {
        case .size20WeightBold: return 20
        case .size16WeightBold, .size16WeightSemiBold: return 16
        case .size14WeightSemiBold, .size14WeightRegular, .size14LightMonospaced: return 14
        case .size12WeightRegular: return 12
        }
    }
    
    var weight: Font.Weight {
        switch self {
        case .size20WeightBold, .size16WeightBold: return .bold
        case .size16WeightSemiBold, .size14WeightSemiBold: return .semibold
        case .size14WeightRegular, .size12WeightRegular: return .regular
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
