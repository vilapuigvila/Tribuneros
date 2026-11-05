//
//  Paddock.TeamDetail.swift
//  Tribuneros
//
//  The team screen (Kit look) a Teams row opens (route `paddockTeam(TeamItem)`): the team's name,
//  division and flag over the roster from its PCS page (`Service.getPCSTeamPage`). For now it is a
//  riders list only; the page also carries KPIs, victories and staff for later sections.
//

import SwiftUI

extension Paddock {

    /// One roster row: PCS prints the surname in capitals ("PHILIPSEN Jasper").
    struct TeamRiderItem: Identifiable, Equatable, Hashable, Sendable {
        var id: String { path }
        let path: String
        let name: String
        let countryCode: String
        /// PCS ranking position and points, nil when the page prints none.
        let rank: Int?
        let points: Int?
        let photoURL: URL?

        /// "DEL GROSSO Tibor" → "DT": the first letter of the surname and of the given name, the avatar's
        /// stand-in when PCS has no photo. A single word gives its first two letters.
        var initials: String {
            let words = name.split { !$0.isLetter }.map(String.init)
            guard let first = words.first, let last = words.last else { return "" }
            let letters = words.count > 1
                ? String(first.prefix(1)) + String(last.prefix(1))
                : String(first.prefix(2))
            return letters.uppercased()
        }

        /// What the rider screen opens on: the name, flag and the rider's PCS page.
        var asRider: Rider {
            Rider(
                name: name,
                countryCode: countryCode,
                url: Service.pcsAbsoluteURL(path)
            )
        }

        static let placeholders: [TeamRiderItem] = (1...6).map { index in
            TeamRiderItem(
                path: "placeholder-\(index)",
                name: "RIDER Name placeholder", // l10n:ignore: redacted stand-in
                countryCode: "",
                rank: 10,
                points: 1000,
                photoURL: nil
            )
        }
    }

    /// Roster in PCS's order, riders with a PCS rank first (by rank), the rest after in page order.
    static func teamRiders(from page: DTO.PCSTeamPage) -> [TeamRiderItem] {
        let items = page.riders.map {
            TeamRiderItem(
                path: $0.path,
                name: $0.name,
                countryCode: $0.countryCode,
                rank: $0.rank,
                points: $0.points,
                photoURL: $0.photoURL
            )
        }
        let ranked = items.filter { $0.rank != nil }.sorted { ($0.rank ?? 0) < ($1.rank ?? 0) }
        return ranked + items.filter { $0.rank == nil }
    }

    /// "team/lidl-trek-2027" → "team/lidl-trek-2026"; nil when the path doesn't end in a year.
    static func previousSeasonPath(_ path: String) -> String? {
        guard let year = pathYear(path),
              path.hasSuffix("-\(year)")
        else {
            return nil
        }
        return String(path.dropLast(4)) + String(year - 1)
    }

    /// PCS publishes no rider photos for a new season's page until the season starts: riders without
    /// one take the photo from the previous season's page (same rider path). Others are left as they are.
    static func fillingPhotos(
        _ riders: [TeamRiderItem],
        from previous: DTO.PCSTeamPage?
    ) -> [TeamRiderItem] {
        guard let previous else { return riders }
        let photos = Dictionary(
            previous.riders.compactMap { rider in rider.photoURL.map { (rider.path, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        return riders.map { rider in
            guard rider.photoURL == nil, let photo = photos[rider.path] else { return rider }
            return TeamRiderItem(
                path: rider.path,
                name: rider.name,
                countryCode: rider.countryCode,
                rank: rider.rank,
                points: rider.points,
                photoURL: photo
            )
        }
    }

    /// Loads the roster once per screen; "Try again" restarts a failed load.
    @MainActor
    final class TeamDetailModel: ObservableObject {
        @Published private(set) var riders: Listing<TeamRiderItem> = .loading

        let team: TeamItem
        private let fetch: (String) async -> DTO.PCSTeamPage?
        private var task: Task<Void, Never>?

        init(
            team: TeamItem,
            fetch: @escaping (String) async -> DTO.PCSTeamPage? = { await Service.getPCSTeamPage(path: $0) }
        ) {
            self.team = team
            self.fetch = fetch
        }

        func load() {
            guard task == nil else { return }
            if case .loaded = riders { return }
            if case .failed = riders { riders = .loading }
            task = Task { [weak self, team, fetch] in
                let page = await fetch(team.path)
                guard let self else { return }
                if let page {
                    var riders = Paddock.teamRiders(from: page)
                    if riders.contains(where: { $0.photoURL == nil }),
                       let previousPath = Paddock.previousSeasonPath(team.path) {
                        riders = Paddock.fillingPhotos(
                            riders,
                            from: await fetch(previousPath)
                        )
                    }
                    self.riders = .loaded(riders)
                } else {
                    self.riders = .failed
                }
                self.task = nil
            }
        }
    }

    struct TeamDetailView: View {
        @StateObject private var model: TeamDetailModel

        let openRider: (RiderContext) -> Void

        init(
            team: TeamItem,
            openRider: @escaping (RiderContext) -> Void
        ) {
            self.openRider = openRider
            _model = StateObject(wrappedValue: TeamDetailModel(team: team))
        }

        var body: some View {
            let loading = model.riders == .loading
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(loading: loading)
                    VStack(spacing: 0) {
                        switch model.riders {
                        case .loading:
                            TeamRiderRows(riders: TeamRiderItem.placeholders)
                                .redacted(reason: .placeholder)
                                .shimmering()
                                .disabled(true)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(L10n.tr("Loading the riders"))
                        case .failed:
                            message(
                                L10n.tr("Couldn't load the team from ProCyclingStats."),
                                retry: true
                            )
                        case .loaded(let riders):
                            if riders.isEmpty {
                                message(L10n.tr("No riders listed."), retry: false)
                            } else {
                                TeamRiderRows(
                                    riders: riders,
                                    onTap: { openRider(.teamRider($0.asRider)) }
                                )
                            }
                        }
                    }
                    .kitCard()
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.tribuneru(.kitPageBackground))
            .preferredColorScheme(.dark)
            .navigationTitle(model.team.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("paddock.teamDetail")
            .onAppear { model.load() }
        }

        private func header(loading: Bool) -> some View {
            HStack(spacing: 14) {
                TribuneruText(
                    content: model.team.monogram,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.kitAvatarText),
                    lineLimit: 1
                )
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.tribuneru(.kitAvatar)))
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: model.team.name,
                        style: .vaporSectionTitle,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 2
                    )
                    let meta = [
                        model.team.division,
                        loading ? "" : L10n.tr("%lld RIDERS", model.riders.items.count)
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                    if !meta.isEmpty {
                        TribuneruText(
                            content: meta,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
                Spacer(minLength: 8)
                if !model.team.countryCode.isEmpty {
                    VaporFlagView(countryCode: model.team.countryCode)
                }
            }
            .accessibilityElement(children: .combine)
        }

        private func message(
            _ text: String,
            retry: Bool
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                TribuneruText(
                    content: text,
                    style: .vaporMeta,
                    color: .tribuneru(.kitTextSecondary),
                    lineLimit: 2
                )
                if retry {
                    Button {
                        model.load()
                    } label: {
                        TribuneruText(
                            content: L10n.tr("Try again"),
                            style: .vaporSeeAll,
                            color: .tribuneru(.kitAccent)
                        )
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(
                            Capsule().fill(Color.tribuneru(.kitAccent).opacity(0.14))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct TeamRiderRows: View {
        let riders: [TeamRiderItem]
        /// nil leaves the rows inert (the redacted placeholders).
        var onTap: ((TeamRiderItem) -> Void)?

        var body: some View {
            VStack(spacing: 0) {
                ForEach(Array(riders.enumerated()), id: \.element.id) { index, rider in
                    if index > 0 {
                        RiderDivider(look: .kit)
                    }
                    if let onTap {
                        Button {
                            onTap(rider)
                        } label: {
                            TeamRiderRowView(rider: rider)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("paddock.teamRider.\(rider.path)")
                    } else {
                        TeamRiderRowView(rider: rider)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    struct TeamRiderRowView: View {
        let rider: TeamRiderItem

        /// "1985 pts" or, with a rank, "#6 · 1985 pts".
        private var meta: String {
            var parts: [String] = []
            if let rank = rider.rank { parts.append("#\(rank)") }
            if let points = rider.points { parts.append(L10n.tr("%@ pts", String(points))) }
            return parts.joined(separator: " · ")
        }

        var body: some View {
            HStack(spacing: 12) {
                CachedImageView(
                    imageUrl: rider.photoURL,
                    cornerRadius: 0,
                    presentation: .racePhoto,
                    fallback: AnyView(
                        TribuneruText(
                            content: rider.initials,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitAvatarText),
                            lineLimit: 1
                        )
                    )
                )
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.tribuneru(.kitAvatar)))
                .clipShape(Circle())
                TribuneruText(
                    content: rider.name,
                    style: .vaporRowTitle,
                    color: .tribuneru(.kitTextPrimary),
                    lineLimit: 2
                )
                Spacer(minLength: 8)
                if !meta.isEmpty {
                    TribuneruText(
                        content: meta,
                        style: .vaporMonoMeta,
                        color: .tribuneru(.kitTextSecondary),
                        lineLimit: 1
                    )
                }
                if !rider.countryCode.isEmpty {
                    VaporFlagView(countryCode: rider.countryCode)
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 80)
            .accessibilityElement(children: .combine)
        }
    }
}
