//
//  YoutubeView.swift
//  Tribuneros
//
//  Created by albert vila on 13/3/25.
//

import SwiftUI

struct YoutubeVideoView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SafariView(url: url)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Color.tribuneru(.gray)
                            .opacity(0.4)
                    )
                    .cornerRadius(8)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}
