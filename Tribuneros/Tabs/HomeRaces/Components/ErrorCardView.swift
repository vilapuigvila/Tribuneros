//
//  ErrorCardView.swift
//  Tribuneros
//
//  Created by albert vila puigvila on 5/11/25.
//

import SwiftUI

struct ErrorCardView: View {
    let title: String
    let message: String
    let icon: String
    let primaryButtonTitle: String
    let showTryAgainButton: Bool
    let primaryAction: () -> Void
    
    init(
        title: String,
        message: String,
        icon: String,
        primaryButtonTitle: String,
        showTryAgainButton: Bool,
        primaryAction: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.primaryButtonTitle = primaryButtonTitle
        self.showTryAgainButton = showTryAgainButton
        self.primaryAction = primaryAction
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporNegative))
                .padding(.top, 20)
                .accessibilityHidden(true)

            TribuneruText(
                content: title,
                style: .vaporRowTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            .multilineTextAlignment(.center)

            TribuneruText(
                content: message,
                style: .vaporRowMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 4
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.bottom, showTryAgainButton ? 0 : 20)
            
            if showTryAgainButton {
                Button(action: primaryAction) {
                    TribuneruText(
                        content: primaryButtonTitle,
                        style: .vaporRowTitle,
                        color: .tribuneru(.vaporPageBackground)
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Color.tribuneru(.vaporAccent),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.tribuneru(.vaporCardSurface),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
    
    static func emptyData(showTryAgainButton: Bool, action: @escaping () -> Void) -> Self {
        ErrorCardView(
            title: L10n.tr("No info available"),
            message: L10n.tr("We couldn’t find any race data right now. Try again in a moment."),
            icon: "exclamationmark.triangle.fill",
            primaryButtonTitle: L10n.tr("Try again"),
            showTryAgainButton: showTryAgainButton,
            primaryAction: action
        )
    }
    static func generic(message: String, showTryAgainButton: Bool, action: @escaping () -> Void) -> Self {
        ErrorCardView(
            title: L10n.tr("Something went wrong"),
            message: message,
            icon: "xmark.octagon.fill",
            primaryButtonTitle: L10n.tr("Try again"),
            showTryAgainButton: showTryAgainButton,
            primaryAction: action
        )
    }
}
