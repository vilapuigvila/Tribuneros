//
//  HateZone.MainView.swift
//  Tribuneros
//
//  Created by albert vila on 13/3/25.
//

import SwiftUI
import SafariServices
import WebKit

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


struct WebView: UIViewRepresentable {
    let url: URL
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
    }

    @State private var canGoBack = false
    @State private var canGoForward = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) { }
}

struct HateZoneView: View {
    
//    @ObservedObject var viewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    let url: URL?
    
    var body: some View {
        HateZone.MainView(url: url)
    }
}

extension HateZone {
    
    
    struct MainView: View {
        let url: URL?
        @State private var webView: WKWebView = WKWebView()
        
        var body: some View {
            if let url {
                /*
                VStack {
                    HStack {
                        Button(action: {
                            if webView.canGoBack {
                                webView.goBack()
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .padding()
                                .foregroundColor(webView.canGoBack ? .blue : .gray)
                        }
                        .disabled(!webView.canGoBack)

                        Button(action: {
                            webView.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .padding()
                        }

                        Button(action: {
                            if webView.canGoForward {
                                webView.goForward()
                            }
                        }) {
                            Image(systemName: "arrow.right")
                                .padding()
                                .foregroundColor(webView.canGoForward ? .blue : .gray)
                        }
                    }
//                    .edgesIgnoringSafeArea(.all)
                    .background(.red)
                    WebView(url: url)
//                    Spacer()
                }*/
//                .edgesIgnoringSafeArea(.all)
                SafariView(url: url)
            } else {
                Text("No URL provided")
            }
        }
    }
}

#Preview {
    HateZone.MainView(url: URL(string: "http://ciclismo2005.com")!)
}
