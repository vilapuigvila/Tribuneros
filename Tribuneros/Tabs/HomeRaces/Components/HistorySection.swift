//
//  HistorySection.swift
//  Tribuneros
//
//  "History": a banner standing in for past seasons until there is data behind it.
//

import SwiftUI

struct HistorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                title: "History",
                showsInertSeeAll: true
            )
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
                    .shadow(color: Color.tribuneru(.black).opacity(0.5), radius: 6, x: 0, y: 1)
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
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.tribuneru(.vaporTextPrimary).opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.history.banner")
    }
}
