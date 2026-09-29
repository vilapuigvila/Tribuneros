//
//  HomeHeaders.swift
//  Tribuneros
//
//  The screen header and the title row every Today Races section starts with.
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

/// A section title, one line, with "See all" at the trailing edge when there is a list behind it.
/// `reservesTapHeight: false` is for a title with a control directly under it: the 44pt tap
/// area of "See all" then overflows the row instead of making it taller.
struct HomeSectionHeader: View {
    let title: String
    var seeAll: (() -> Void)?
    var reservesTapHeight: Bool = true
    var seeAllIdentifier: String = "seeAll"
    /// Draws "See all" without an action, for a section whose list doesn't exist yet.
    var showsInertSeeAll: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            TribuneruText(
                content: title,
                style: .vaporHeading,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
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

struct SeeAllLabel: View {
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

/// The spoiler chip, left aligned under a section title.
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

/// One line inside a card-shaped box, for a section that has nothing to show yet.
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
