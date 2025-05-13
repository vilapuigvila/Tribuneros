//
//  EmptyResultsCardView.swift
//  Tribuneros
//
//  Created by albert vila on 12/3/25.
//

import SwiftUI

struct EmptyResultsCardView: View {
    @State private var animateInfoText = false
    @State private var textOffset: CGFloat = -120
    
    let title: String
    let info: String
    let delaySlideInfo: Double
    
    init(title: String, info: String, delaySlideInfo: Double) {
        self.title = title
        self.info = info
        self.delaySlideInfo = delaySlideInfo
    }
    
    var body: some View {
        VStack {
            HStack {
                TribuneruText(content: title, style: .size16WeightBold)
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
            
                Spacer()
            }
            
            TribunerosDivider(height: 0.5, color: Color.gray.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 12)
            
            Spacer()

            GeometryReader { geo in
                Text(info)
                    .tribuneruStyle(.size14LightMonospaced)
                    .padding(12)
                    .offset(x: textOffset)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delaySlideInfo) {
                            withAnimation(
                                Animation.linear(duration: 12)
                                    .repeatForever(autoreverses: false)
                            ) {
                                textOffset = geo.size.width
                            }
                        }
                    }
            }
//            .frame(height: 30)
//            .debugBackground()
            
            Spacer()
        }
    }
}

#Preview {
    VStack {
        EmptyResultsCardView(
            title: "Results today",
            info: "No results found for your search",
            delaySlideInfo: 1
        )
        .background(.blue.opacity(0.5))
        .cornerRadius(8)
    }
    .frame(height: 140)
}
