//
//  SafariView.swift
//  Tribuneros
//
//  Created by albert vila on 13/3/25.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL?

    func makeUIViewController(context: Context) -> SFSafariViewController {
        if let url {
            return SFSafariViewController(url: url)
        } else {
            return SFSafariViewController(url: URL(string: "https://apple.com")!)
        }
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
