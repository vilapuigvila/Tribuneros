//
//  Settings.MainView.swift
//  Tribuneros
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: Settings.ViewModel<Settings.InteractorImpl>
    @Environment(\.replayOnboarding) private var replayOnboarding

    var body: some View {
        Settings.MainView(state: viewModel.stateView) { action in
            viewModel.action(action)
            if case .didTapShowOnboarding = action {
                replayOnboarding()
            }
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            switch destination {
            case .settingsAcknowledgements:
                Settings.AcknowledgementsView()
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.tr("SETTINGS"))
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension Settings {

    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets
        @State private var showsLanguages = false

        let state: Settings.ViewState
        let action: (Settings.Action) -> Void

        private var version: String {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            return version.isEmpty ? "" : "v\(version)"
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    HideResultsTile(
                        isOn: state.hidesResults,
                        toggle: { action(.didToggleHidesResults(!state.hidesResults)) }
                    )
                    HStack(spacing: 12) {
                        SettingsTile(
                            title: L10n.tr("Language"),
                            subtitle: state.languageTitle,
                            systemImage: "globe",
                            identifier: "settings.language"
                        ) {
                            showsLanguages = true
                        }
                        SettingsTile(
                            title: L10n.tr("Onboarding"),
                            subtitle: L10n.tr("Watch it again"),
                            systemImage: "play.circle",
                            identifier: "settings.onboarding"
                        ) {
                            action(.didTapShowOnboarding)
                        }
                    }
                    AcknowledgementsRow {
                        action(.didTapAcknowledgements)
                    }
                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showsLanguages) {
                LanguageSheet(languages: state.languages) { code in
                    showsLanguages = false
                    action(.didSelectLanguage(code))
                }
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(Color.tribuneru(.vaporCardSurface))
                .preferredColorScheme(.dark)
            }
        }

        private var header: some View {
            HStack(spacing: 12) {
                TribuneruText(
                    content: L10n.tr("Settings"),
                    style: .vaporSectionTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                Spacer(minLength: 0)
                TribuneruText(
                    content: version,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .padding(.top, 16)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.header")
        }
    }
}

extension Settings {

    struct AcknowledgementsView: View {
        var body: some View {
            ScrollView {
                SettingsPanel {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.tribuneru(.vaporAccent))
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            HStack(spacing: 12) {
                                TribuneruText(
                                    content: L10n.tr("Music provided by Ciscu Bates"),
                                    style: .vaporRowTitle,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 2
                                )
                                Image("FaceIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(2)
                                    .frame(
                                        width: 24,
                                        height: 24
                                    )
                                    .background(
                                        Color.tribuneru(.white(level: 1)),
                                        in: Circle()
                                    )
                                    .accessibilityHidden(true)
                            }
                            TribuneruText(
                                content: L10n.tr("© 2026 Ciscu Bates. All rights reserved."),
                                style: .vaporRowMeta,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 2
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 52)
                    .background(
                        Color.tribuneru(.vaporCardSurface),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.acknowledgements.music")
                }
                .padding(16)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.tr("Acknowledgements"))
        }
    }
}

/// The section panel is darker than the rows on it.
private struct SettingsPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .padding(8)
        .background(
            Color.tribuneru(.vaporPageBackground).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.tribuneru(.vaporTextPrimary).opacity(0.08))
        }
    }
}

private extension View {
    func settingsCard(
        fill: Color = .tribuneru(.vaporCardSurface),
        border: Color = Color.tribuneru(.vaporTextPrimary).opacity(0.08)
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(border, lineWidth: 1)
            )
    }
}

/// The wide tile that flips the spoiler mode in place.
private struct HideResultsTile: View {
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toggle()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 22, weight: .regular))
                        .animation(Settings.SpoilerModePreview.switchAnimation) {
                            $0.foregroundColor(isOn ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary))
                        }
                    Spacer(minLength: 8)
                    HideResultsSwitch(isOn: isOn)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        TribuneruText(
                            content: L10n.tr("Hide results"),
                            style: .vaporBannerTitle,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 1
                        )
                        TribuneruText(
                            content: isOn
                                ? L10n.tr("Results stay hidden until you press and hold them.")
                                : L10n.tr("Results are shown as soon as you open the app."),
                            style: .vaporRowMeta,
                            color: .tribuneru(.vaporTextMuted),
                            lineLimit: 3
                        )
                        .multilineTextAlignment(.leading)
                        .contentTransition(.opacity)
                        .animation(
                            Settings.SpoilerModePreview.switchAnimation,
                            value: isOn
                        )
                    }
                    Spacer(minLength: 0)
                    Settings.SpoilerModePreview(isOn: isOn)
                        .accessibilityIdentifier("settings.hideResults.preview")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Settings.SpoilerModePreview.switchAnimation) {
                $0.settingsCard(
                    fill: isOn
                        ? Color.tribuneru(.vaporAccent).opacity(0.12)
                        : .tribuneru(.vaporCardSurface),
                    border: isOn
                        ? Color.tribuneru(.vaporAccent).opacity(0.4)
                        : Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("Hide results"))
        .accessibilityValue(isOn ? L10n.tr("ON") : L10n.tr("OFF"))
        .accessibilityAddTraits([.isButton, .isToggle])
        .accessibilityIdentifier("settings.hideResults")
    }
}

/// The tile's switch: the knob slides in step with the preview changing mode.
private struct HideResultsSwitch: View {
    private static let knob: CGFloat = 22
    private static let inset: CGFloat = 3

    let isOn: Bool

    var body: some View {
        TribuneruText(
            content: isOn ? L10n.tr("ON") : L10n.tr("OFF"),
            style: .vaporSpoilerChip,
            color: isOn ? .tribuneru(.vaporPageBackground) : .tribuneru(.vaporTextSecondary),
            lineLimit: 1
        )
        .fixedSize()
        .padding(.leading, isOn ? 11 : Self.knob + Self.inset + 7)
        .padding(.trailing, isOn ? Self.knob + Self.inset + 7 : 11)
        .frame(
            minWidth: 66,
            minHeight: Self.knob + 2 * Self.inset
        )
        .background(
            Color.tribuneru(isOn ? .vaporAccent : .vaporTagNeutral),
            in: Capsule()
        )
        .overlay(alignment: isOn ? .trailing : .leading) {
            Circle()
                .fill(Color.tribuneru(isOn ? .vaporTextPrimary : .vaporTextSecondary))
                .shadow(
                    color: .tribuneru(.vaporPageBackground).opacity(0.35),
                    radius: 1.5,
                    y: 1
                )
                .frame(
                    width: Self.knob,
                    height: Self.knob
                )
                .padding(Self.inset)
        }
        .animation(
            Settings.SpoilerModePreview.switchAnimation,
            value: isOn
        )
    }
}

private struct SettingsTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporAccent))
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: title,
                        style: .vaporRowTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: subtitle,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .settingsCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

private struct AcknowledgementsRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "heart")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextMuted))
                    .accessibilityHidden(true)
                TribuneruText(
                    content: L10n.tr("Acknowledgements"),
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .settingsCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("Acknowledgements"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("settings.acknowledgements")
    }
}

/// The language picker: choosing one applies it at once and closes the sheet.
private struct LanguageSheet: View {
    let languages: [Settings.Representable.Language]
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TribuneruText(
                content: L10n.tr("Language"),
                style: .vaporHeading,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            .padding(.top, 20)
            .padding(.bottom, 6)
            ForEach(languages) { language in
                LanguageRow(language: language) {
                    select(language.id)
                }
            }
            TribuneruText(
                content: L10n.tr("More languages are coming."),
                style: .vaporRowMeta,
                color: .tribuneru(.vaporTextSecondary)
            )
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .accessibilityIdentifier("settings.language.footer")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LanguageRow: View {
    let language: Settings.Representable.Language
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                TribuneruText(
                    content: language.title,
                    style: .vaporRowTitle,
                    color: .tribuneru(language.isSelected ? .vaporAccent : .vaporTextPrimary),
                    lineLimit: 1
                )
                Spacer(minLength: 8)
                if language.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.tribuneru(.vaporAccent))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                language.isSelected
                    ? Color.tribuneru(.vaporAccent).opacity(0.12)
                    : .clear,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.title)
        .accessibilityAddTraits(language.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("settings.language.\(language.id)")
    }
}
