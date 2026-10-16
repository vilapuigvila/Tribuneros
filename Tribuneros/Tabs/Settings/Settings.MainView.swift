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
            case .settingsLanguage:
                Settings.LanguageView(state: viewModel.stateView) {
                    viewModel.action($0)
                }
            case .settingsAcknowledgements:
                Settings.AcknowledgementsView()
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.tr("SETTINGS"))
    }
}

extension Settings {

    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets

        let state: Settings.ViewState
        let action: (Settings.Action) -> Void

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    SettingsPanel {
                        SettingsRow(
                            title: L10n.tr("Show onboarding again"),
                            detail: nil,
                            systemImage: "play.circle",
                            identifier: "settings.onboarding"
                        ) {
                            action(.didTapShowOnboarding)
                        }
                        SettingsRow(
                            title: L10n.tr("Language"),
                            detail: state.languageTitle,
                            systemImage: "globe",
                            identifier: "settings.language"
                        ) {
                            action(.didTapLanguage)
                        }
                        SettingsRow(
                            title: L10n.tr("Acknowledgements"),
                            detail: nil,
                            systemImage: "heart",
                            identifier: "settings.acknowledgements"
                        ) {
                            action(.didTapAcknowledgements)
                        }
                    }
                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                }
                .padding(16)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
        }
    }

    struct LanguageView: View {
        let state: Settings.ViewState
        let action: (Settings.Action) -> Void

        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    SettingsPanel {
                        ForEach(state.languages) { language in
                            LanguageRow(language: language) {
                                action(.didSelectLanguage(language.id))
                            }
                        }
                    }
                    TribuneruText(
                        content: L10n.tr("More languages are coming."),
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("settings.language.footer")
                }
                .padding(16)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.tr("LANGUAGE"))
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
            .navigationTitle(L10n.tr("ACKNOWLEDGEMENTS"))
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

private struct SettingsRow: View {
    let title: String
    let detail: String?
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporAccent))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                TribuneruText(
                    content: title,
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                Spacer(minLength: 8)
                if let detail {
                    TribuneruText(
                        content: detail,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                Color.tribuneru(.vaporCardSurface),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
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
                    color: .tribuneru(.vaporTextPrimary),
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
                Color.tribuneru(.vaporCardSurface),
                in: RoundedRectangle(cornerRadius: 12)
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
