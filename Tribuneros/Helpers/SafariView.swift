//
//  SafariView.swift
//  Tribuneros
//
//  Created by albert vila on 13/3/25.
//

import SwiftUI
import SafariServices

/// Safari in the app. Present it full screen with `.webPage(_:)`, never push it: it brings its
/// own ✕, toolbar and share button, so inside a navigation stack the controls appear twice.
struct SafariView: UIViewControllerRepresentable {
    let url: URL?
    /// Opens straight in Reader when Safari finds an article on the page; ignored otherwise.
    var prefersReader = false
    /// Called when the user taps Safari's ✕.
    var onDone: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        configuration.entersReaderIfAvailable = prefersReader
        let controller = SFSafariViewController(
            url: url ?? URL(string: "https://apple.com")!,
            configuration: configuration
        )
        controller.dismissButtonStyle = .close
        controller.preferredBarTintColor = UIColor(Color.tribuneru(.vaporPageBackground))
        controller.preferredControlTintColor = UIColor(Color.tribuneru(.vaporAccent))
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        context.coordinator.onDone = onDone
    }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDone()
        }
    }
}

/// A web page to show full screen in Safari.
struct WebPage: Identifiable {
    let url: URL
    var prefersReader = false
    var id: URL { url }
}

extension View {
    /// Shows `page` full screen in Safari while it's set; Safari's ✕ clears it.
    func webPage(_ page: Binding<WebPage?>) -> some View {
        fullScreenCover(item: page) { shown in
            SafariView(
                url: shown.url,
                prefersReader: shown.prefersReader
            ) {
                page.wrappedValue = nil
            }
            .ignoresSafeArea()
        }
    }
}
