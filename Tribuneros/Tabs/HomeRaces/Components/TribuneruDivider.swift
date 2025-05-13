//
//  TribuneruDivider.swift
//  Tribuneros
//
//  Created by albert vila on 13/5/25.
//

import SwiftUI

struct TribunerosDivider: View {
    let height: CGFloat
    let color: Color
    
    init(height: CGFloat = 0.5, color: Color = .gray.opacity(0.6)) {
        self.height = height
        self.color = color
    }
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
    }
}
