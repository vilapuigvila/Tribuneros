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
        case .greenCardBackground:
            Color.green.opacity(0.2)
        case .blueMissingInfoBackground:
            Color.blue.opacity(0.2)
        }
    }
    
    enum Palette {
        case greenCardBackground
        case blueMissingInfoBackground
    }
}
