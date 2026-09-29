//
//  Paddock.MainView.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import SwiftUI

struct PaddockView: View {
    @ObservedObject var viewModel: Paddock.ViewModel<Paddock.InteractorImpl>

    var body: some View {
        Paddock.MainView(state: viewModel.stateView) {
            viewModel.action($0)
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            switch destination {
            case .web(let url):
                SafariView(url: url)
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("PADDOCK")
    }
}

extension Paddock {

    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets

        let state: Paddock.ViewState
        let action: (Paddock.Action) -> Void

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    switch state.press {
                    case .loading:
                        PressPanel(items: PressItem.placeholders) { _ in }
                            .redacted(reason: .placeholder)
                            .disabled(true)
                    case .loaded(let items) where !items.isEmpty:
                        PressPanel(items: items) { url in
                            action(.didTapOnLink(url))
                        }
                    case .loaded:
                        EmptyView()
                    }

                    FeedPanel(
                        filter: state.filter,
                        feed: state.feed,
                        action: action
                    )

                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                }
                .padding(16)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
            .onAppear {
                action(.didAppear)
            }
        }
    }
}

#if DEBUG
#Preview("Paddock") {
    let rider = Paddock.Rider(
        name: "POGAČAR Tadej",
        countryCode: "si",
        url: nil
    )
    let state = Paddock.ViewState(
        press: .loaded([
            .init(
                url: URL(string: "https://escapecollective.com")!,
                name: "Escape Collective",
                domain: "escapecollective.com"
            ),
            .init(
                url: URL(string: "https://www.cyclingnews.com")!,
                name: "cyclingnews.com",
                domain: nil
            )
        ]),
        filter: .all,
        feed: .loaded([
            .init(
                title: "Today",
                cards: [
                    .birthdays(
                        .init(
                            id: "b",
                            entries: [
                                .init(
                                    rider: rider,
                                    age: "28"
                                )
                            ]
                        )
                    ),
                    .program(
                        .init(
                            id: "p",
                            timeAgo: "15m",
                            rider: rider,
                            changes: [
                                .init(
                                    isAdded: false,
                                    raceName: "World Championships ME - Road Race"
                                )
                            ]
                        )
                    )
                ]
            ),
            .init(
                title: "Yesterday",
                cards: [
                    .transfer(
                        .init(
                            id: "t",
                            date: "20/09",
                            rider: rider,
                            teamName: "Unibet Rose Rockets"
                        )
                    )
                ]
            )
        ])
    )
    return Paddock.MainView(state: state) { _ in }
}

#Preview("Paddock - loading") {
    Paddock.MainView(state: .idle) { _ in }
}
#endif
