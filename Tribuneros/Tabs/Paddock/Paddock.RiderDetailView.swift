//
//  Paddock.RiderDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 29/9/26.
//

import SwiftUI

extension Paddock {

    /// Native rider screen, opened from a Paddock transfer or program card. The card's own data
    /// (new team, or the added/dropped races) is shown right away; the photo, current team and
    /// profile facts come from the rider's PCS page, parsed best-effort on the device — each of
    /// those hides when it comes back empty.
    struct RiderDetailView: View {
        let context: RiderContext
        let openURL: (URL) -> Void
        /// Fetches the PCS rider page; injectable so previews never hit the network.
        private let loadPage: (URL) async -> DTO.PCSRiderPage?

        @State private var page: DTO.PCSRiderPage?
        @State private var isLoading: Bool

        init(
            context: RiderContext,
            page: DTO.PCSRiderPage? = nil,
            loadPage: @escaping (URL) async -> DTO.PCSRiderPage? = {
                await Service.getPCSRiderPage(url: $0)
            },
            openURL: @escaping (URL) -> Void
        ) {
            self.context = context
            self.openURL = openURL
            self.loadPage = loadPage
            _page = State(initialValue: page)
            let isLoading = page == nil && context.rider.url != nil
            _isLoading = State(initialValue: isLoading)
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profilePanel

                    switch context {
                    case .transfer(let card):
                        TransferPanel(card: card)
                    case .program(let card):
                        ProgramPanel(card: card)
                    }

                    if isLoading {
                        CXRiderFactsPanel(facts: DTO.CXRiderPage.Fact.placeholders)
                            .redacted(reason: .placeholder)
                            .disabled(true)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Loading the rider")
                    } else if let facts = page?.facts, !facts.isEmpty {
                        CXRiderFactsPanel(facts: facts)
                    }

                    if let riderURL = context.rider.url {
                        Button {
                            openURL(riderURL)
                        } label: {
                            VaporCard {
                                VaporMoreInfoLink(title: "rider page on ProCyclingStats")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
            .navigationTitle("Rider")
            .task {
                guard isLoading, let url = context.rider.url else { return }
                page = await loadPage(url)
                isLoading = false
            }
        }

        // MARK: - Profile -

        private var profilePanel: some View {
            VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
                CXDetailTag(
                    title: tag,
                    color: .tribuneru(.vaporAccent)
                )
            } content: {
                HStack(alignment: .center, spacing: 16) {
                    CXRiderAvatar(url: page?.imageURL)

                    VStack(alignment: .leading, spacing: 6) {
                        TribuneruText(
                            content: context.rider.name,
                            style: .vaporSectionTitle,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 2
                        )
                        if !context.rider.countryCode.isEmpty {
                            HStack(spacing: 8) {
                                VaporFlagView(countryCode: context.rider.countryCode)
                                TribuneruText(
                                    content: nationality ?? context.rider.countryCode.uppercased(),
                                    style: .vaporMeta,
                                    color: .tribuneru(.vaporTextSecondary),
                                    lineLimit: 1
                                )
                            }
                        }
                        if let team = page?.team {
                            TribuneruText(
                                content: team,
                                style: .vaporMeta,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 2
                            )
                        }
                    }
                }
            }
        }

        private var tag: String {
            switch context {
            case .transfer: "Transfer"
            case .program: "Program update"
            }
        }

        private var nationality: String? {
            page?.facts.first { $0.label.lowercased().contains("nationality") }?.value
        }
    }
}

// MARK: - Context panels -

private extension Paddock {

    struct TransferPanel: View {
        let card: TransferCard

        var body: some View {
            VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
                VaporSectionHeader(title: "Transfer")
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    VaporCard(spacing: 6) {
                        TribuneruText(
                            content: "JOINS",
                            style: .vaporGroupLabel,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.tribuneru(.vaporAccent))
                            TribuneruText(
                                content: card.teamName,
                                style: .vaporRaceNameNext,
                                color: .tribuneru(.vaporTextPrimary),
                                lineLimit: 2
                            )
                        }
                    }
                    CXStatTile(
                        label: "Announced",
                        value: card.date
                    )
                }
            }
        }
    }

    struct ProgramPanel: View {
        let card: ProgramCard

        var body: some View {
            VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
                VaporSectionHeader(title: "Program update") {
                    TribuneruText(
                        content: "\(card.timeAgo) ago",
                        style: .vaporScreenDate,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                    .padding(.top, 12)
                }
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    changes(
                        title: "Added",
                        isAdded: true
                    )
                    changes(
                        title: "Dropped",
                        isAdded: false
                    )
                }
            }
        }

        @ViewBuilder
        private func changes(
            title: String,
            isAdded: Bool
        ) -> some View {
            let races = card.changes
                .filter { $0.isAdded == isAdded }
                .map(\.raceName)
            if !races.isEmpty {
                VaporCard(spacing: 8) {
                    TribuneruText(
                        content: title.uppercased(),
                        style: .vaporGroupLabel,
                        color: isAdded ? .tribuneru(.vaporLive) : .tribuneru(.vaporNegative),
                        lineLimit: 1
                    )
                    ForEach(races.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TribuneruText(
                                content: isAdded ? "+" : "−",
                                style: .vaporChangeSign,
                                color: isAdded ? .tribuneru(.vaporLive) : .tribuneru(.vaporNegative)
                            )
                            .frame(width: 10, alignment: .leading)
                            .accessibilityHidden(true)
                            TribuneruText(
                                content: races[index],
                                style: .vaporRaceNameResult,
                                color: .tribuneru(.vaporTextPrimary),
                                lineLimit: 2
                            )
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG

// MARK: - Mocks -

private extension Paddock.Rider {
    static var mock: Self {
        .init(
            name: "POGAČAR Tadej",
            countryCode: "si",
            url: URL(string: "https://www.procyclingstats.com/rider/tadej-pogacar")
        )
    }
}

private extension DTO.PCSRiderPage {
    static var mock: Self {
        .init(
            name: "Tadej Pogačar",
            imageURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg"),
            team: "UAE Team Emirates - XRG",
            facts: [
                .init(label: "Date of birth", value: "21st September 1998 (28)"),
                .init(label: "Nationality", value: "Slovenia"),
                .init(label: "Weight", value: "66 kg"),
                .init(label: "Height", value: "1.76 m"),
                .init(label: "Place of birth", value: "Komenda")
            ]
        )
    }
}

// MARK: - Previews -

#Preview("Paddock rider - transfer") {
    NavigationStack {
        Paddock.RiderDetailView(
            context: .transfer(
                .init(
                    id: "t",
                    date: "20/09",
                    rider: .mock,
                    teamName: "Unibet Rose Rockets"
                )
            ),
            page: .mock
        ) { _ in }
    }
}

#Preview("Paddock rider - program") {
    NavigationStack {
        Paddock.RiderDetailView(
            context: .program(
                .init(
                    id: "p",
                    timeAgo: "16h",
                    rider: .mock,
                    changes: [
                        .init(
                            isAdded: true,
                            raceName: "Il Lombardia"
                        ),
                        .init(
                            isAdded: true,
                            raceName: "Tre Valli Varesine"
                        ),
                        .init(
                            isAdded: false,
                            raceName: "World Championships ME - Road Race"
                        )
                    ]
                )
            ),
            page: .mock
        ) { _ in }
    }
}

#Preview("Paddock rider - page unavailable") {
    NavigationStack {
        Paddock.RiderDetailView(
            context: .transfer(
                .init(
                    id: "t",
                    date: "20/09",
                    rider: .mock,
                    teamName: "Unibet Rose Rockets"
                )
            ),
            loadPage: { _ in nil }
        ) { _ in }
    }
}

#Preview("Paddock rider - loading") {
    NavigationStack {
        Paddock.RiderDetailView(
            context: .transfer(
                .init(
                    id: "t",
                    date: "20/09",
                    rider: .mock,
                    teamName: "Unibet Rose Rockets"
                )
            ),
            loadPage: { _ in
                // Never finishes, so the preview stays on the placeholders.
                try? await Task.sleep(for: .seconds(3600))
                return nil
            }
        ) { _ in }
    }
}

#endif
