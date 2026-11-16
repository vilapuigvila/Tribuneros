//
//  RaceAlerts.Views.swift
//  Tribuneros
//

import SwiftUI

/// The CX Zone header's round bell: outline when nothing is followed, filled with a count, slashed when iOS blocks notifications.
struct RaceAlertsBellButton: View {
    static let size: CGFloat = 44

    let bell: RaceAlerts.Bell
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(
                    width: Self.size,
                    height: Self.size
                )
                .background(
                    Circle().fill(fill)
                )
                .overlay(
                    Circle().strokeBorder(border, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if case .following(let count) = bell {
                        TribuneruText(
                            content: "\(count)",
                            style: .vaporTagSmall,
                            color: .tribuneru(.mudPageBackground),
                            lineLimit: 1
                        )
                        .frame(
                            minWidth: 18,
                            minHeight: 18
                        )
                        .background(
                            Circle().fill(Color.tribuneru(.mudAccent))
                        )
                        .overlay(
                            Circle().strokeBorder(Color.tribuneru(.mudPageBackground), lineWidth: 2)
                        )
                        .offset(
                            x: 4,
                            y: -4
                        )
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("Race alerts"))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("cx.alerts.bell")
    }

    private var symbol: String {
        switch bell {
        case .none: "bell"
        case .following: "bell.fill"
        case .blocked: "bell.slash"
        }
    }

    private var iconColor: Color {
        switch bell {
        case .none: .tribuneru(.mudTextPrimary)
        case .following: .tribuneru(.mudAccent)
        case .blocked: .tribuneru(.mudTextMuted)
        }
    }

    private var fill: Color {
        if case .following = bell {
            return Color.tribuneru(.mudAccent).opacity(0.14)
        }
        return .tribuneru(.mudCardSurface)
    }

    private var border: Color {
        if case .following = bell {
            return Color.tribuneru(.mudAccent).opacity(0.4)
        }
        return Color.tribuneru(.mudTextPrimary).opacity(0.08)
    }

    private var accessibilityValue: String {
        switch bell {
        case .none: L10n.tr("Off")
        case .following(let count): L10n.tr("%lld series", count)
        case .blocked: L10n.tr("Notifications are off in iOS")
        }
    }
}

/// The "Race alerts" bottom sheet, Mud look: one switch per followable series.
struct RaceAlertsSheet: View {
    let sheet: RaceAlerts.Sheet
    let action: (RaceAlerts.Action) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: L10n.tr("Race alerts"),
                        style: .vaporHeading,
                        color: .tribuneru(.mudTextPrimary),
                        lineLimit: 1
                    )
                    .accessibilityIdentifier("raceAlerts.title")
                    TribuneruText(
                        content: L10n.tr("A notification when each Men Elite race starts and when it finishes. Winners stay hidden."),
                        style: .vaporRowMeta,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 3
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .padding(.top, 24)
                if sheet.isBlocked {
                    blockedBanner
                }
                VStack(spacing: 0) {
                    ForEach(Array(sheet.rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            MudDivider()
                        }
                        RaceAlertsRow(row: row) { isOn in
                            if isOn {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            action(.didToggle(row.series, isOn: isOn))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .mudCard()
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: L10n.tr("No alerts for these series"),
                        style: .vaporTagSmall,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: [
                            CXRaces.RaceSeries.exactCross,
                            .championships,
                            .others
                        ]
                        .map(\.title)
                        .joined(separator: " · "),
                        style: .vaporRowMeta,
                        color: .tribuneru(.mudTextMuted),
                        lineLimit: 2
                    )
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("raceAlerts.excluded")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .onAppear {
            action(.didRequestAuthorizationRefresh)
        }
    }

    private var blockedBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.tribuneru(.mudAccent))
                    .accessibilityHidden(true)
                TribuneruText(
                    content: L10n.tr("Notifications are off in iOS"),
                    style: .vaporRowTitle,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 2
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("raceAlerts.blocked")
            Button {
                action(.didTapOpenSystemSettings)
            } label: {
                TribuneruText(
                    content: L10n.tr("Open iOS Settings"),
                    style: .vaporLink,
                    color: .tribuneru(.mudPageBackground),
                    lineLimit: 1
                )
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .background(
                    Capsule().fill(Color.tribuneru(.mudAccent))
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("raceAlerts.openSettings")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.tribuneru(.mudAccent).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.tribuneru(.mudAccent).opacity(0.4), lineWidth: 1)
        )
    }
}

private struct RaceAlertsRow: View {
    let row: RaceAlerts.Row
    let toggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                TribuneruText(
                    content: row.title,
                    style: .vaporRowTitle,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
                TribuneruText(
                    content: row.subtitle,
                    style: .vaporRowMeta,
                    color: .tribuneru(row.isOn ? .mudAccent : .mudTextSecondary),
                    lineLimit: 2
                )
                .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("raceAlerts.row.\(row.id)")
            Toggle(
                isOn: Binding(
                    get: { row.isOn },
                    set: { toggle($0) }
                )
            ) {
                EmptyView()
            }
            .labelsHidden()
            .accessibilityLabel(row.title)
            .tint(.tribuneru(.mudAccent))
            .disabled(!row.isEnabled)
            .accessibilityIdentifier("raceAlerts.switch.\(row.id)")
        }
        .frame(minHeight: 64)
        .opacity(row.isEnabled ? 1 : 0.45)
        .animation(
            .easeInOut(duration: 0.2),
            value: row.subtitle
        )
    }
}

#if DEBUG
#Preview("Race alerts") {
    RaceAlertsSheet(
        sheet: RaceAlerts.ViewModel<RaceAlerts.InteractorImpl>.mapToViewState(
            from: RaceAlerts.Domain(
                followed: [.worldCup],
                authorization: .allowed
            )
        ).settingsSheet
    ) { _ in }
    .preferredColorScheme(.dark)
}

#Preview("Race alerts, blocked") {
    RaceAlertsSheet(
        sheet: RaceAlerts.ViewModel<RaceAlerts.InteractorImpl>.mapToViewState(
            from: RaceAlerts.Domain(
                followed: [.worldCup],
                authorization: .blocked
            )
        ).settingsSheet
    ) { _ in }
    .preferredColorScheme(.dark)
}
#endif

extension View {
    /// The Race alerts sheet, the same from CX Zone and from Settings.
    func raceAlertsSheet(
        isPresented: Binding<Bool>,
        sheet: RaceAlerts.Sheet,
        action: @escaping (RaceAlerts.Action) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            RaceAlertsSheet(
                sheet: sheet,
                action: action
            )
            .presentationDetents([.height(600), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackground(Color.tribuneru(.mudPageBackground))
            .preferredColorScheme(.dark)
        }
    }
}
