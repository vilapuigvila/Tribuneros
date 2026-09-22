//
//  VaporSectionPanel.swift
//  Tribuneros
//
//  The "Vapor" redesign, originally Home-only: each section (Next to
//  finish, Results today/yesterday, Races tomorrow) is one rounded,
//  coloured panel holding a large title and a 2-column grid of race cards.
//  Also rolled out to CX Zone and Hate Zone — see `VaporPanel` below for
//  the freeform (non-grid) variant those use.
//
//  See `agent-doc/home_redesign_spec.md` for the full spec this implements.

import SwiftUI

/// One coloured, rounded section on the Home screen: a header followed by a
/// 2-column grid of cards, both painted the section's own panel colour.
///
/// The panel colour must stay darker than `Color.tribuneru(.vaporCardSurface)`
/// — the cards read as floating above it. See the spec's §1.
struct VaporSectionPanel<Header: View, Content: View>: View {
    let panelColor: Color
    /// When `true`, the card grid collapses to zero height and fades out —
    /// used for the spoiler toggle. `header` (and whatever control lives in
    /// it, e.g. the spoiler chip) stays outside this and is always shown:
    /// hiding it along with the content would make it impossible to ever
    /// un-hide the section again.
    var contentHidden: Bool = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    private static var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.top, 28)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            LazyVGrid(columns: Self.columns, spacing: 10) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .opacity(contentHidden ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: contentHidden ? 0 : nil)
            .clipped()
            .animation(.interpolatingSpring(.smooth, initialVelocity: 0.5), value: contentHidden)
        }
        .background(panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// A rounded, coloured panel holding a header and freeform content — the
/// non-grid sibling of `VaporSectionPanel`, used where a section holds a
/// single preview card or a list rather than a 2-column card grid (CX Zone's
/// "Next races" / "Latest results" / "Standings" sections).
///
/// Same colour rule as `VaporSectionPanel`: `panelColor` must stay darker
/// than `Color.tribuneru(.vaporCardSurface)`.
struct VaporPanel<Header: View, Content: View>: View {
    let panelColor: Color
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header()
                .padding(.top, 28)
                .padding(.horizontal, 20)

            content()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// The small "more info" trailing link used at the bottom of a Vapor preview
/// card (CX Zone's section previews) to point at the full list screen.
struct VaporMoreInfoLink: View {
    var title: String = "more info"

    var body: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            TribuneruText(
                content: title,
                style: .vaporMeta,
                color: .tribuneru(.vaporAccent),
                lineLimit: 1
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporAccent))
        }
    }
}

/// The title row shared by every panel: a big title on the leading edge, with
/// an optional leading accessory (the "live" dot) or trailing accessory (a
/// date, or the spoiler toggle).
struct VaporSectionHeader<Trailing: View>: View {
    let title: String
    var showsLiveDot: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsLiveDot {
                Circle()
                    .fill(Color.tribuneru(.vaporLive))
                    .frame(width: 6, height: 6)
                    .padding(.top, 14)
            }
            // Wraps rather than truncates: at 30pt, a section name sharing
            // the row with the spoiler chip ("Results yesterday") doesn't
            // reliably fit on one line at phone width.
            TribuneruText(
                content: title,
                style: .vaporSectionTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            if Trailing.self != EmptyView.self {
                Spacer(minLength: 12)
            }
            trailing()
                .fixedSize()
        }
    }
}

extension VaporSectionHeader where Trailing == EmptyView {
    init(title: String, showsLiveDot: Bool = false) {
        self.init(title: title, showsLiveDot: showsLiveDot) { EmptyView() }
    }
}

/// A 16×12 flag, or a neutral placeholder when no image is available.
/// `init(countryCode:)` builds the app's usual `flagcdn.com` URL (used by
/// Home, whose DTOs only carry a country code); `init(url:)` takes an
/// already-resolved flag URL directly (CX Zone's DTOs carry full URLs).
struct VaporFlagView: View {
    private let resolvedURL: URL?

    init(countryCode: String) {
        resolvedURL = countryCode.isEmpty ? nil : URL(string: "https://flagcdn.com/w40/\(countryCode).png")
    }

    init(url: URL?) {
        resolvedURL = url
    }

    var body: some View {
        Group {
            if let resolvedURL {
                CachedImageView(imageUrl: resolvedURL, cornerRadius: 1)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.tribuneru(.vaporTextSecondary).opacity(0.18))
            }
        }
        .frame(width: 16, height: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 1)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
    }
}

/// The "Spoiler on/off" toggle. Visually a small Space Mono chip, but the
/// tappable area is expanded to 44×44 — the chip alone measures well under
/// the iOS minimum (see the spec's §6).
struct VaporSpoilerChip: View {
    let isSpoilerModeOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TribuneruText(
                content: isSpoilerModeOn ? "Spoiler is on" : "Spoiler is off",
                style: .vaporSpoilerChip,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.tribuneru(.vaporTextSecondary), lineWidth: 0.5)
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Vapor panel") {
    ZStack {
        Color.tribuneru(.vaporPageBackground).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 20) {
                VaporSectionPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
                    VaporSectionHeader(title: "Next to finish", showsLiveDot: true)
                } content: {
                    Color.tribuneru(.vaporCardSurface)
                        .frame(height: 100)
                        .cornerRadius(8)
                    Color.tribuneru(.vaporCardSurface)
                        .frame(height: 100)
                        .cornerRadius(8)
                }

                VaporSectionPanel(panelColor: .tribuneru(.vaporPanelToday)) {
                    VaporSectionHeader(title: "Results today") {
                        VaporSpoilerChip(isSpoilerModeOn: false) {}
                    }
                } content: {
                    Color.tribuneru(.vaporCardSurface)
                        .frame(height: 100)
                        .cornerRadius(8)
                }
            }
            .padding(16)
        }
    }
    .preferredColorScheme(.dark)
}
#endif
