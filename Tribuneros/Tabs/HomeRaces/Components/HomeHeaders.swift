//
//  HomeHeaders.swift
//  Tribuneros
//

import SwiftUI

struct HomeScreenHeader: View {
    let date: Date

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEddMMM")
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bicycle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextPrimary))
                TribuneruText(
                    content: "Races",
                    style: .vaporSectionTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
            }
            Spacer(minLength: 0)
            TribuneruText(
                content: Self.dateFormatter.string(from: date),
                style: .vaporScreenDate,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.header")
    }
}

/// Under the header when the page is an old cached copy, since the header always shows today's date.
struct StaleCopyNotice: View {
    let staleCopy: HomeRaces.StaleCopy

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 6) {
                Image(systemName: staleCopy.isOffline ? "wifi.slash" : "exclamationmark.arrow.circlepath")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                TribuneruText(
                    content: text(now: context.date),
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.staleNotice")
    }

    private func text(now: Date) -> String {
        let reason = staleCopy.isOffline ? "Offline" : "Couldn't refresh"
        let updated = Self.formatter.localizedString(
            for: min(staleCopy.savedAt, now),
            relativeTo: now
        )
        return "\(reason) · updated \(updated)"
    }
}

/// With the navigation bar hidden, scrolled content would run under the status bar; this fades it out.
struct StatusBarScrim: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    var body: some View {
        let page = Color.tribuneru(.vaporPageBackground)
        LinearGradient(
            stops: [
                .init(color: page, location: 0),
                .init(color: page, location: 0.7),
                .init(color: page.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: safeAreaInsets.top + 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HomeSpoiler {
    let isOn: Bool
    let identifier: String
    let action: () -> Void
}

/// A title row and its content. With a spoiler chip under the title the content folds away (and is
/// not built) while spoilers are off; without one the content sits 14pt under the title.
struct HomeSection<Content: View>: View {
    let title: String
    var seeAll: (() -> Void)?
    var seeAllIdentifier: String = ""
    var showsInertSeeAll: Bool = false
    var spoiler: HomeSpoiler?
    @ViewBuilder let content: () -> Content

    @ViewBuilder
    var body: some View {
        if let spoiler {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    header(reservesTapHeight: false)
                    HomeSpoilerChip(
                        isSpoilerModeOn: spoiler.isOn,
                        action: spoiler.action,
                        identifier: spoiler.identifier
                    )
                }
                FoldingContent(isShown: spoiler.isOn, content: content)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header(reservesTapHeight: true)
                content()
            }
        }
    }

    private func header(reservesTapHeight: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                TribuneruText(
                    content: title,
                    style: .vaporHeading,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                // A spoiler chip only exists when there are results; the dot hints at them while hidden.
                if let spoiler, !spoiler.isOn {
                    PulsingBullet()
                }
            }
            Spacer(minLength: 0)
            if let seeAll {
                Button(action: seeAll) {
                    SeeAllLabel()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, reservesTapHeight ? 0 : -8)
                .accessibilityLabel("See all \(title)")
                .accessibilityIdentifier(seeAllIdentifier)
            } else if showsInertSeeAll {
                SeeAllLabel()
                    .frame(minHeight: 44)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: reservesTapHeight ? 44 : nil)
    }
}

private struct PulsingBullet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let dot = Circle()
            .fill(Color.tribuneru(.vaporAccent))
            .frame(
                width: 8,
                height: 8
            )
            .accessibilityHidden(true)
        if reduceMotion {
            dot
        } else {
            // Fade out to 0, hold 0.5s, fade back in, forever.
            dot.phaseAnimator([true, false]) { content, isShown in
                content.opacity(isShown ? 1 : 0)
            } animation: { isShown in
                isShown ? .easeInOut(duration: 1.6).delay(0.5) : .easeInOut(duration: 1.6)
            }
        }
    }
}

/// The scroll screen behind a "See all": no navigation title, the page background, dark scheme.
struct HomeListScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SeeAllLabel: View {
    var body: some View {
        HStack(spacing: 2) {
            TribuneruText(
                content: "See all",
                style: .vaporLink,
                color: .tribuneru(.vaporAccent),
                lineLimit: 1
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporAccent))
        }
    }
}

struct HomeSpoilerChip: View {
    let isSpoilerModeOn: Bool
    let action: () -> Void
    let identifier: String

    var body: some View {
        HStack(spacing: 0) {
            VaporSpoilerChip(
                isSpoilerModeOn: isSpoilerModeOn,
                action: action
            )
            .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
        }
    }
}

struct HomeEmptyNote: View {
    let text: String

    var body: some View {
        HStack {
            TribuneruText(
                content: text,
                style: .vaporRowMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .homeCard()
    }
}
