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
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("SETTINGS")
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
                            title: "Show onboarding again",
                            detail: nil,
                            systemImage: "play.circle",
                            identifier: "settings.onboarding"
                        ) {
                            action(.didTapShowOnboarding)
                        }
                        SettingsRow(
                            title: "Language",
                            detail: state.languageTitle,
                            systemImage: "globe",
                            identifier: "settings.language"
                        ) {
                            action(.didTapLanguage)
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
                        content: "More languages are coming.",
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
            .navigationTitle("LANGUAGE")
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
        .accessibilityIdentifier("settings.language.\(language.title.lowercased())")
    }
}
