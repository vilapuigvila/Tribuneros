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
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.accentColor.opacity(0.9),
                                Color.accentColor.opacity(0.2),
                                Color.accentColor.opacity(0.9)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotate)
            }
            .frame(width: 72, height: 72)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12)
            .onAppear { rotate = true }

            TribuneruText(content: title, style: .size14WeightRegular)
                .font(.body)
                .bold()
                .lineLimit(nil)
                .multilineTextAlignment(.center)

            if let subtitle {
                TribuneruText(content: subtitle, style: .size13WeightRegular, color: .secondary)
                    .font(.footnote)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
