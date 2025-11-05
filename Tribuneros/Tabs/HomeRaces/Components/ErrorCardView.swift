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
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.red, Color.orange)
                .padding(.top, 16)

            Text(title)
                .font(.title3).bold()
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.bottom, showTryAgainButton ? 0 : 16)
            
            if showTryAgainButton {
                Button(primaryButtonTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.25),
                            Color.orange.opacity(0.15),
                            Color.black.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
//        .onTapGesture { primaryAction() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
    
    static func emptyData(showTryAgainButton: Bool, action: @escaping () -> Void) -> Self {
        ErrorCardView(
            title: "No info available",
            message: "We couldn’t find any race data right now. Try again in a moment.",
            icon: "exclamationmark.triangle.fill",
            primaryButtonTitle: "Try again",
            showTryAgainButton: showTryAgainButton,
            primaryAction: action
        )
    }
    static func generic(message: String, showTryAgainButton: Bool, action: @escaping () -> Void) -> Self {
        ErrorCardView(
            title: "Something went wrong",
            message: message,
            icon: "xmark.octagon.fill",
            primaryButtonTitle: "Try again",
            showTryAgainButton: showTryAgainButton,
            primaryAction: action
        )
    }
}
