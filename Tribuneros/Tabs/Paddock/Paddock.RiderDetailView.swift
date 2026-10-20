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
        let openSeasonResults: (SeasonResultsContext) -> Void
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
            openSeasonResults: @escaping (SeasonResultsContext) -> Void
        ) {
            self.context = context
            self.openSeasonResults = openSeasonResults
            self.loadPage = loadPage
            _page = State(initialValue: page)
            let isLoading = page == nil && context.rider.url != nil
            _isLoading = State(initialValue: isLoading)
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    profilePanel

                    switch context {
                    case .transfer(let card):
                        TransferPanel(card: card)
                    case .program(let card):
                        ProgramPanel(card: card)
                    case .birthday(let entry):
                        BirthdayPanel(entry: entry)
                    }

                    if isLoading {
                        CXRiderFactsPanel(
                            facts: DTO.CXRiderPage.Fact.placeholders,
                            look: .kit
                        )
                            .redacted(reason: .placeholder)
                            .disabled(true)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(L10n.tr("Loading the rider"))
                    } else if let facts = page?.facts, !facts.isEmpty {
                        CXRiderFactsPanel(
                            facts: facts,
                            look: .kit
                        )
                    }

                    if !isLoading {
                        RiderSectionsView(
                            sections: sections,
                            riderName: page?.name ?? context.rider.name,
                            openSeasonResults: openSeasonResults
                        )
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(RiderLook.kit.page)
            .preferredColorScheme(.dark)
            .navigationTitle(L10n.tr("Rider"))
            .task {
                guard isLoading, let url = context.rider.url else { return }
                page = await loadPage(url)
                isLoading = false
            }
        }

        // MARK: - Profile -

        private var profilePanel: some View {
            RiderHeaderCard(
                look: .kit,
                tags: [(tag, true)],
                avatarURL: page?.imageURL,
                name: context.rider.name,
                flag: context.rider.countryCode.isEmpty ? nil : VaporFlagView(countryCode: context.rider.countryCode),
                country: context.rider.countryCode.isEmpty ? nil : (nationality ?? context.rider.countryCode.uppercased()),
                team: page?.team
            )
        }

        private var sections: RiderSections {
            RiderSections(page: page)
        }

        private var tag: String {
            switch context {
            case .transfer: L10n.tr("Transfer")
            case .program: L10n.tr("Program update")
            case .birthday: L10n.tr("Birthday")
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
            RiderPanel(
                look: .kit,
                title: L10n.tr("Transfer")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    RiderCardBox(
                        look: .kit,
                        spacing: 6
                    ) {
                        TribuneruText(
                            content: L10n.tr("JOINS"),
                            style: .vaporGroupLabel,
                            color: RiderLook.kit.secondary,
                            lineLimit: 1
                        )
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(RiderLook.kit.accent)
                            TribuneruText(
                                content: card.teamName,
                                style: .vaporRaceNameNext,
                                color: RiderLook.kit.primary,
                                lineLimit: 2
                            )
                        }
                    }
                    CXStatTile(
                        label: L10n.tr("Announced"),
                        value: card.date,
                        look: .kit
                    )
                }
            }
        }
    }

    struct BirthdayPanel: View {
        let entry: BirthdaysCard.Entry

        var body: some View {
            RiderPanel(
                look: .kit,
                title: L10n.tr("Birthday")
            ) {
                CXStatTile(
                    label: L10n.tr("Age today"),
                    value: entry.age,
                    look: .kit
                )
                .accessibilityIdentifier("paddock.rider.birthday")
            }
        }
    }

    struct ProgramPanel: View {
        let card: ProgramCard

        var body: some View {
            RiderPanel(
                look: .kit,
                title: L10n.tr("Program update"),
                trailing: {
                    TribuneruText(
                        content: L10n.tr("%@ ago", card.timeAgo),
                        style: .vaporScreenDate,
                        color: RiderLook.kit.secondary
                    )
                }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    changes(
                        title: L10n.tr("Added"),
                        isAdded: true
                    )
                    changes(
                        title: L10n.tr("Dropped"),
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
                RiderCardBox(
                    look: .kit,
                    spacing: 8
                ) {
                    TribuneruText(
                        content: title.uppercased(with: L10n.locale),
                        style: .vaporGroupLabel,
                        color: isAdded ? .tribuneru(.kitAdded) : .tribuneru(.kitDropped),
                        lineLimit: 1
                    )
                    ForEach(races.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TribuneruText(
                                content: isAdded ? "+" : "−",
                                style: .vaporChangeSign,
                                color: isAdded ? .tribuneru(.kitAdded) : .tribuneru(.kitDropped)
                            )
                            .frame(width: 10, alignment: .leading)
                            .accessibilityHidden(true)
                            TribuneruText(
                                content: races[index],
                                style: .vaporRaceNameResult,
                                color: RiderLook.kit.primary,
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
                .init(label: "Date of birth", value: "21st September 1998 (28)"), // l10n:ignore: PCS fact label, mock data
                .init(label: "Nationality", value: "Slovenia"), // l10n:ignore: PCS fact label, mock data
                .init(label: "Weight", value: "66 kg"), // l10n:ignore: PCS fact label, mock data
                .init(label: "Height", value: "1.76 m"), // l10n:ignore: PCS fact label, mock data
                .init(label: "Place of birth", value: "Komenda") // l10n:ignore: PCS fact label, mock data
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
