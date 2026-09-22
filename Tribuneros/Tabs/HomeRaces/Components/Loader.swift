//
//  Loader.swift
//  Tribuneros
//
//  Created by albert vila puigvila on 5/11/25.
//

import SwiftUI

struct LoaderView: View {
    let title: String
    let subtitle: String?

    @State private var rotate = false

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.tribuneru(.vaporTextPrimary).opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.tribuneru(.vaporAccent).opacity(0.9),
                                Color.tribuneru(.vaporAccent).opacity(0.2),
                                Color.tribuneru(.vaporAccent).opacity(0.9)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotate)
            }
            .frame(width: 72, height: 72)
            .shadow(color: Color.tribuneru(.vaporAccent).opacity(0.35), radius: 12)
            .onAppear { rotate = true }

            TribuneruText(
                content: title,
                style: .vaporRaceNameNext,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            .multilineTextAlignment(.center)

            if let subtitle {
                TribuneruText(
                    content: subtitle,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
                .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
