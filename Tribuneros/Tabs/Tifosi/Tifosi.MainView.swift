//
//  Tifosi.MainView.swift
//  Tribuneros
//

import SwiftUI

struct TifosiView: View {
    @ObservedObject var viewModel: Tifosi.ViewModel<Tifosi.InteractorImpl>

    var body: some View {
        Tifosi.MainView(state: viewModel.stateView) {
            viewModel.action($0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.tr("Tifosi"))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.action(.didAppear)
        }
    }
}

extension Tifosi {

    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets

        let state: Tifosi.ViewState
        let action: (Tifosi.Action) -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Header(dateLine: state.dateLine)
                        .padding(.top, 16)
                    ChipsRow(chips: state.chips) { action(.didSelectChannel($0)) }
                    if state.showsTVGuide {
                        TVGuideView(
                            screen: state.tv,
                            onTapChannel: { action(.didTapTVChannel($0)) },
                            onSelectDay: { action(.didSelectTVDay($0)) },
                            onRetry: { action(.didRetryTV) }
                        )
                    } else {
                        LiveBanner(race: state.race)
                        if let leader = state.leader {
                            LeaderPanel(post: leader)
                        }
                        ChaseSection(posts: state.chase)
                        BroomStrip()
                    }
                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.tribuneru(.tifosiPageBackground))
            .overlay(alignment: .top) {
                StatusBarScrim(tint: .tribuneru(.tifosiPageBackground))
            }
            .preferredColorScheme(.dark)
            .animation(.easeOut(duration: 0.2), value: state.chips)
        }
    }
}

// MARK: - Header -
extension Tifosi {

    struct Header: View {
        let dateLine: String

        var body: some View {
            HStack(spacing: 12) {
                Image("TabTifosi")
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: 28,
                        height: 28
                    )
                    .foregroundColor(.tribuneru(.tifosiAccent))
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: L10n.tr("Tifosi"),
                        style: .vaporSectionTitle,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: dateLine,
                        style: .vaporScreenDate,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
                Button {
                } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.tribuneru(.tifosiTextPrimary))
                        .frame(
                            width: 40,
                            height: 40
                        )
                        .background(Circle().fill(Color.tribuneru(.tifosiCard)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("Channels"))
            }
            .accessibilityIdentifier("tifosi.header")
        }
    }
}

// MARK: - Chips -
extension Tifosi {

    struct ChipsRow: View {
        let chips: [Representable.Chip]
        let onSelect: (Channel) -> Void

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            onSelect(chip.channel)
                        } label: {
                            TribuneruText(
                                content: chip.title,
                                style: .vaporLink,
                                color: .tribuneru(chip.isSelected ? .tifosiOnAccent : .tifosiTextMuted),
                                lineLimit: 1
                            )
                            .padding(.horizontal, 16)
                            .frame(minHeight: 38)
                            .background(
                                Capsule().fill(Color.tribuneru(chip.isSelected ? .tifosiAccent : .tifosiCard))
                            )
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!chip.isEnabled)
                        .opacity(chip.isEnabled ? 1 : 0.4)
                        .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
                        .accessibilityIdentifier("tifosi.chip.\(chip.channel.rawValue)")
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Live banner -
extension Tifosi {

    struct LiveBanner: View {
        let race: String

        var body: some View {
            HStack(spacing: 12) {
                TribuneruText(
                    content: L10n.tr("LIVE"),
                    style: .vaporTagSmall,
                    color: .white,
                    lineLimit: 1
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.tribuneru(.vaporLiveRed)))
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: L10n.tr("%@ · the crowd is loud", race),
                        style: .vaporBannerTitle,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: L10n.tr(
                            "%lld km to go · %lld posts in the last %lld min",
                            23,
                            47,
                            10
                        ),
                        style: .vaporBannerSubtitle,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tribuneru(.tifosiTextSecondary))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.tribuneru(.tifosiCard))
            )
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Leader -
extension Tifosi {

    struct JerseyShape: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(
                    x: rect.minX + x * s,
                    y: rect.minY + y * s
                )
            }
            var path = Path()
            path.move(to: point(8, 3))
            path.addLine(to: point(3, 6))
            path.addLine(to: point(5, 11))
            path.addLine(to: point(7, 10))
            path.addLine(to: point(7, 21))
            path.addLine(to: point(17, 21))
            path.addLine(to: point(17, 10))
            path.addLine(to: point(19, 11))
            path.addLine(to: point(21, 6))
            path.addLine(to: point(16, 3))
            path.addCurve(
                to: point(12, 6),
                control1: point(15.5, 4.7),
                control2: point(14, 6)
            )
            path.addCurve(
                to: point(8, 3),
                control1: point(10, 6),
                control2: point(8.5, 4.7)
            )
            path.closeSubpath()
            return path
        }
    }

    struct LeaderPanel: View {
        let post: Post

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    JerseyShape()
                        .fill(Color.tribuneru(.tifosiAccent))
                        .frame(
                            width: 20,
                            height: 20
                        )
                    TribuneruText(
                        content: L10n.tr("HEAD OF THE RACE"),
                        style: .vaporTag,
                        color: .tribuneru(.tifosiAccent),
                        lineLimit: 1
                    )
                    Spacer(minLength: 0)
                    TribuneruText(
                        content: L10n.tr("most shared · %@", post.age),
                        style: .vaporMonoMeta,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Avatar(initials: post.initials)
                        VStack(alignment: .leading, spacing: 1) {
                            TribuneruText(
                                content: post.handle,
                                style: .vaporRowTitle,
                                color: .tribuneru(.tifosiTextPrimary),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: L10n.tr("via %@", post.source),
                                style: .vaporRowMeta,
                                color: .tribuneru(.tifosiTextSecondary),
                                lineLimit: 1
                            )
                        }
                        Spacer(minLength: 0)
                        KindTag(title: post.kind.tag)
                    }
                    TribuneruText(
                        content: post.text,
                        style: .vaporHeroSubtitle,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 8
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        if let shares = post.shares {
                            TribuneruText(
                                content: L10n.tr("%@ shares", shares),
                                style: .vaporMonoMeta,
                                color: .tribuneru(.tifosiTextMuted),
                                lineLimit: 1
                            )
                        }
                        if let likes = post.likes {
                            TribuneruText(
                                content: L10n.tr("%@ likes", likes),
                                style: .vaporMonoMeta,
                                color: .tribuneru(.tifosiTextMuted),
                                lineLimit: 1
                            )
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.tribuneru(.tifosiCard))
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.tribuneru(.tifosiPanel))
            )
        }
    }

    struct Avatar: View {
        let initials: String

        var body: some View {
            TribuneruText(
                content: initials,
                style: .vaporPill,
                color: .tribuneru(.tifosiTagText),
                lineLimit: 1
            )
            .frame(
                width: 36,
                height: 36
            )
            .background(Circle().fill(Color.tribuneru(.tifosiTag)))
        }
    }

    struct KindTag: View {
        let title: String

        var body: some View {
            TribuneruText(
                content: title,
                style: .vaporFeedTag,
                color: .tribuneru(.tifosiTagText),
                lineLimit: 1
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.tribuneru(.tifosiTag)))
        }
    }
}

// MARK: - Chase -
extension Tifosi {

    struct ChaseSection: View {
        let posts: [Post]

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    TribuneruText(
                        content: L10n.tr("The chase"),
                        style: .vaporHeading,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 1
                    )
                    Spacer(minLength: 8)
                    TribuneruText(
                        content: L10n.tr("gap = how stale it is"),
                        style: .vaporMeta,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                if posts.isEmpty {
                    TribuneruText(
                        content: L10n.tr("Nobody is chasing on this channel."),
                        style: .vaporRowMeta,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 2
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.tribuneru(.tifosiPanel))
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            HStack(alignment: .top, spacing: 12) {
                                TribuneruText(
                                    content: post.age,
                                    style: .vaporRowTime,
                                    color: .tribuneru(gapColor(post, index: index)),
                                    lineLimit: 1
                                )
                                .frame(width: 64, alignment: .leading)
                                ChaseCard(post: post)
                            }
                        }
                    }
                }
            }
        }

        private func gapColor(_ post: Post, index: Int) -> Color.Palette {
            if post.isStale { return .tifosiTextSecondary }
            return index == 0 ? .tifosiAccent : .tifosiTextMuted
        }
    }

    struct ChaseCard: View {
        let post: Post

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TribuneruText(
                        content: "\(post.handle) · \(post.source)", // l10n:ignore
                        style: .vaporRowTitle,
                        color: .tribuneru(post.isStale ? .tifosiTextSecondary : .tifosiTextPrimary),
                        lineLimit: 1
                    )
                    Spacer(minLength: 0)
                    KindTag(title: post.kind.tag)
                }
                TribuneruText(
                    content: post.text,
                    style: .vaporRowMeta,
                    color: .tribuneru(post.isStale ? .tifosiTextSecondary : .tifosiTextMuted),
                    lineLimit: 6
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tribuneru(post.isStale ? .tifosiPanel : .tifosiCard))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        Color.tribuneru(.tifosiLine),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: post.isStale ? [5, 4] : []
                        )
                    )
            )
        }
    }
}

// MARK: - Broom wagon -
extension Tifosi {

    struct BroomStrip: View {
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: "bus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.tribuneru(.tifosiTextSecondary))
                TribuneruText(
                    content: L10n.tr("Broom wagon sweeps posts older than 24 h"),
                    style: .vaporMeta,
                    color: .tribuneru(.tifosiTextSecondary),
                    lineLimit: 2
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tribuneru(.tifosiBroomStrip))
            )
        }
    }
}

#if DEBUG
#Preview("Tifosi") {
    TifosiView(
        viewModel: Tifosi.ViewModel(
            router: Router(),
            interactor: Tifosi.InteractorImpl()
        )
    )
}
#endif
