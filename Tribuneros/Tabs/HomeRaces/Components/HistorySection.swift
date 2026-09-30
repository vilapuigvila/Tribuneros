//
//  HistorySection.swift
//  Tribuneros
//

import SwiftUI

struct HistorySection: View {
    var body: some View {
        HomeSection(
            title: "History",
            showsInertSeeAll: true
        ) {
            HistoryBanner()
        }
    }
}

struct HistoryBanner: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RaceArtView(art: .banner)
            LinearGradient(
                colors: [
                    Color.tribuneru(.vaporPageBackground).opacity(0.88),
                    Color.tribuneru(.vaporPageBackground).opacity(0.55),
                    Color.tribuneru(.vaporPageBackground).opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: "Browse past seasons",
                        style: .vaporBannerTitle,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 1
                    )
                    .artTitleShadow()
                    TribuneruText(
                        content: "Results, standings and more",
                        style: .vaporBannerSubtitle,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.85),
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextPrimary))
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 124)
        .homeCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.history.banner")
    }
}
