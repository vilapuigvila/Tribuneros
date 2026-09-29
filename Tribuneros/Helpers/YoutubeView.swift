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
        SafariView(url: url) {
            dismiss()
        }
        .ignoresSafeArea()
    }
}
