//
//  HomeCardStyle.swift
//  Tribuneros
//

import SwiftUI

extension View {
    func homeCard(cornerRadius: CGFloat = 20) -> some View {
        background(Color.tribuneru(.vaporCardSurface))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.tribuneru(.vaporTextPrimary).opacity(0.08),
                        lineWidth: 1
                    )
            )
    }

    func artTitleShadow() -> some View {
        shadow(color: Color.tribuneru(.black).opacity(0.5), radius: 7, x: 0, y: 1)
    }

    /// Wraps the view in a button that opens `url`, or leaves it as it is without one.
    @ViewBuilder
    func opensPage(_ url: URL?, open: @escaping (URL) -> Void) -> some View {
        if let url {
            Button {
                open(url)
            } label: {
                self
            }
            .buttonStyle(.plain)
        } else {
            self
        }
    }
}

/// Darkens the top and bottom of a painting so tags and titles stay readable over it.
struct ImageScrim: View {
    var top: Double = 0.5
    var topEnd: Double = 0.3
    var bottom: Double = 0.78
    var bottomEnd: Double = 0.54

    var body: some View {
        let page = Color.tribuneru(.vaporPageBackground)
        ZStack {
            LinearGradient(
                colors: [page.opacity(top), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: topEnd)
            )
            LinearGradient(
                colors: [page.opacity(bottom), .clear],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: bottomEnd)
            )
        }
    }
}

/// Content that is built, and its images fetched, only while shown; it grows and fades in and out.
struct FoldingContent<Content: View>: View {
    let isShown: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isShown {
                content()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .animation(.interpolatingSpring(.smooth, initialVelocity: 0.5), value: isShown)
    }
}
