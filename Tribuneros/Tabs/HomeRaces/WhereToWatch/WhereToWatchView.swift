//
//  WhereToWatchView.swift
//  Tribuneros
//
//  The native "Where to watch" screen (route `whereToWatch`). See `HomeRaces.WhereToWatch`.
//

import SwiftUI

struct WhereToWatchView: View {
    private typealias WhereToWatch = HomeRaces.WhereToWatch

    @StateObject private var viewModel: WhereToWatch.ViewModel<WhereToWatch.InteractorImpl>

    init(
        raceKey: HomeRaces.WhereToWatch.RaceKey?,
        router: Router,
        loadPage: @escaping (String?) async -> DTO.CourseDuJourPage? = {
            await Service.getCourseDuJourPage(date: $0)
        }
    ) {
        _viewModel = StateObject(
            wrappedValue: WhereToWatch.ViewModel(
                router: router,
                interactor: WhereToWatch.InteractorImpl(
                    key: raceKey,
                    loadPage: loadPage
                )
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch state.content {
                case .loading:
                    loadingContent
                case .loaded(let heading, let updated, let featured, let sections):
                    dayStrip(state.days)
                    loaded(
                        heading: heading,
                        updated: updated,
                        featured: featured,
                        sections: sections
                    )
                case .failed:
                    dayStrip(state.days)
                    failed
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle("Where to watch")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    // MARK: - Content -

    private var loadingContent: some View {
        let placeholders = WhereToWatch.ViewState.placeholders
        return VStack(alignment: .leading, spacing: 20) {
            dayStrip(placeholders.days)
            if case .loaded(let heading, let updated, let featured, let sections) = placeholders.content {
                loaded(
                    heading: heading,
                    updated: updated,
                    featured: featured,
                    sections: sections
                )
            }
        }
        .redacted(reason: .placeholder)
        .disabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading the schedule")
    }

    private func loaded(
        heading: String,
        updated: String?,
        featured: WhereToWatch.ViewState.Featured?,
        sections: [WhereToWatch.ViewState.Section]
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(
                    content: heading,
                    style: .vaporHeading,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("whereToWatch.heading")

                if let updated {
                    TribuneruText(
                        content: updated,
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
            }

            if let featured {
                featuredView(featured)
            }

            ForEach(sections) { section in
                sectionView(section)
            }
        }
    }

    @ViewBuilder
    private func featuredView(_ featured: WhereToWatch.ViewState.Featured) -> some View {
        switch featured {
        case .race(let race):
            VStack(alignment: .leading, spacing: 12) {
                TribuneruText(
                    content: "YOUR RACE",
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporAccent),
                    lineLimit: 1
                )
                raceCard(
                    race,
                    identifier: "whereToWatch.featured"
                )
            }
        case .notListed(let message):
            VaporCard {
                HStack(spacing: 10) {
                    Image(systemName: "tv")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.tribuneru(.vaporTextSecondary))
                        .frame(width: 18)
                    TribuneruText(
                        content: message,
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 3
                    )
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("whereToWatch.notListed")
        }
    }

    private func sectionView(_ section: WhereToWatch.ViewState.Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                TribuneruText(
                    content: section.title.uppercased(),
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
                Spacer(minLength: 8)
                TribuneruText(
                    content: section.caption,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("whereToWatch.section.\(section.title)")

            ForEach(section.races) { race in
                raceCard(race)
            }
        }
    }

    private func raceCard(
        _ race: WhereToWatch.ViewState.Race,
        identifier: String? = nil
    ) -> some View {
        VaporCard(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if !race.time.isEmpty {
                        TribuneruText(
                            content: race.time,
                            style: .vaporRowTime,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                    if race.isLive {
                        RaceStatusTag(
                            kind: .live,
                            size: .small
                        )
                    }
                }
                TribuneruText(
                    content: race.title,
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 3
                )
                if !race.meta.isEmpty {
                    TribuneruText(
                        content: race.meta,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 2
                    )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(race.accessibilityLabel)
            .accessibilityIdentifier(identifier ?? "whereToWatch.race.\(race.title)")

            if race.channels.isEmpty {
                TribuneruText(
                    content: "No broadcast listed yet",
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextMuted),
                    lineLimit: 1
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(race.channels) { channel in
                        channelRow(channel)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.tribuneru(.vaporAccent),
                    lineWidth: race.isHighlighted ? 1.5 : 0
                )
        )
        .opacity(race.isFinished ? 0.6 : 1)
    }

    private func channelRow(
        _ channel: WhereToWatch.ViewState.Channel
    ) -> some View {
        HStack(spacing: 8) {
            TribuneruText(
                content: channel.name,
                style: .vaporRowTitle,
                color: .tribuneru(.vaporAccent),
                lineLimit: 2
            )
            if !channel.regions.isEmpty {
                TribuneruText(
                    content: channel.regions,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            Spacer(minLength: 8)
            if let time = channel.time {
                TribuneruText(
                    content: time,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("whereToWatch.channel.\(channel.name)")
    }

    // MARK: - Day strip -

    private func dayStrip(_ days: [WhereToWatch.ViewState.Day]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.action(.select(day.id))
                    } label: {
                        VStack(spacing: 2) {
                            TribuneruText(
                                content: day.weekday,
                                style: .vaporGroupLabel,
                                color: day.isSelected ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: day.number,
                                style: .vaporSectionTitle,
                                color: .tribuneru(.vaporTextPrimary),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: day.count,
                                style: .vaporMeta,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 1
                            )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            day.isSelected
                            ? Color.tribuneru(.vaporCardSurface)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.weekday) \(day.number), \(day.count)")
                    .accessibilityAddTraits(day.isSelected ? .isSelected : [])
                    .accessibilityIdentifier("whereToWatch.day.\(index)")
                }
            }
        }
    }

    private var failed: some View {
        VaporCard {
            TribuneruText(
                content: "Couldn't load the schedule.",
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 2
            )
            Button {
                viewModel.action(.retry)
            } label: {
                TribuneruText(
                    content: "Try again",
                    style: .vaporLink,
                    color: .tribuneru(.vaporAccent),
                    lineLimit: 1
                )
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("whereToWatch.retry")
        }
    }
}
