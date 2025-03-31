//
//  HeaderRaceCardView.swift
//  Tribuneros
//
//  Created by albert vila on 14/3/25.
//

import SwiftUI

struct HeaderRaceCardView: View {
    let title: String
    let spoilerModeAction: (() -> Void)?
    let showResultsAction: (() -> Void)?
    init(
        title: String,
        spoilerModeAction: ( () -> Void)? = nil,
        showResultsAction: ( () -> Void)? = nil
    ) {
        self.title = title
        self.spoilerModeAction = spoilerModeAction
        self.showResultsAction = showResultsAction
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
                Spacer()
                
                if let spoilerModeAction, let showResultsAction {
                    HStack(alignment: .center, spacing: 12) {
                        buildButton("Spoiler on/off", action: spoilerModeAction)
                        buildButton("Show", action: showResultsAction)
                            .opacity(1)
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
        Button {let _ = print("avvp tap - ")
            action()
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
        HeaderRaceCardView(title: "Results today") {
            
        } showResultsAction: {
            
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
