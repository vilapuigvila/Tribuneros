//
//  HeaderRaceCardView.swift
//  Tribuneros
//
//  Created by albert vila on 14/3/25.
//

import SwiftUI

struct HeaderRaceCardView: View {
    let title: String
    let isSpoilerModeOn: Bool
    let spoilerModeAction: (() -> Void)?
    
    init(
        title: String,
        isSpoilerModeOn: Bool,
        spoilerModeAction: ( () -> Void)? = nil
    ) {
        self.title = title
        self.isSpoilerModeOn = isSpoilerModeOn
        self.spoilerModeAction = spoilerModeAction
    }
    var body: some View {
        buildTitleNextToFinishCardView()
    }
    
    @ViewBuilder
    private func buildTitleNextToFinishCardView() -> some View {
        VStack {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundColor(.white) // avvp color
                Spacer()
                
                if let spoilerModeAction {
                    HStack(alignment: .center, spacing: 12) {
                        let textSpoilerBtn = isSpoilerModeOn ? "Spoiler is on" : "Spoiler is off"
                        buildButton(textSpoilerBtn, action: spoilerModeAction)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 8)
            
            Rectangle()
                .fill(Color.gray.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 2)
        }
    }
    
    private func buildButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
//            withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                    .padding(.all, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray, lineWidth: 0.5)
                    )
            }
        }
    }
}

#Preview {
    VStack {
        HeaderRaceCardView(title: "Results today", isSpoilerModeOn: false) {
            
        }
        .frame(maxWidth: .infinity)
//        .padding()
        .background(.purple.opacity(0.2))
    }
    .padding()
//    .ignoresSafeArea(.all)
    Spacer()
}

//                            Image(systemName: "eye.slash.fill")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 14, height: 14)
