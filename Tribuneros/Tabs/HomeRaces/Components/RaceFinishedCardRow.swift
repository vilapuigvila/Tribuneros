//
//  RaceFinishedCardRow.swift
//  Tribuneros
//
//  Created by albert vila on 29/4/25.
//

import SwiftUI

struct RaceFinishedRowView: View {
    let race: HomeRaces.Representable.RaceFinished
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            winnerImageSection
                .padding(.trailing, 0)
//                .padding(.vertical, 16)
                .padding(.leading, 8)
            raceDetailsSection
        }
        .frame(maxWidth: .infinity)
//        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Subviews
    
    private var winnerImageSection: some View {
        CachedImageView(imageUrl: race.winnerImgURL)
//        AsyncImageView(url: race.winnerImgURL, cornerRadius: 4)
            .frame(width: 80)
//            .scaleEffect(1.0)
    }
    
    private var raceDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(content: race.race, style: .size20WeightBold)
                
                TribuneruText(
                    content: race.raceDetails,
                    style: .size14WeightSemiBold,
                    color: .white.opacity(0.75)
                )
            }
            .padding(.bottom, 6)
//            .debugBackground()
            
            ForEach(Array(race.podium.enumerated()), id: \.element.id) { index, winner in
                podiumRow(
                    position: winner.position,
                    flag: winner.countryCode,
                    name: winner.name,
                    time: winner.time,
                    isWinner: index == 0
                )
                TribunerosDivider()
            }
        }
        .padding(16)
    }
    
    private func podiumRow(
        position: String,
        flag: String,
        name: String,
        time: String,
        isWinner: Bool
    ) -> some View {
        HStack(spacing: 4) {
            buildPositionAndFlag(position: position, countryCode: flag)
            TribuneruText(
                content: name,
                style: isWinner ? .size16WeightBold : .size16WeightSemiBold,
                color: isWinner ? .white : .white.opacity(0.8)
            )
//            .debugBackground()
            
            Spacer()
            
            TribuneruText(
                content: time,
                style: isWinner ? .size14WeightSemiBold : .size14WeightRegular,
                color: isWinner ? .white : .white.opacity(0.8)
            )
        }
        .padding(.vertical, 10)
    }
    
    private func buildPositionAndFlag(position: String, countryCode: String) -> some View {
        HStack(spacing: 2) {
            TribuneruText(
                content: position,
                style: .size14WeightSemiBold
            )
            AsyncImageView(url: URL(string: "https://flagcdn.com/w40/\(countryCode).png")!)
                .frame(width: 16, height: 12)
                .padding(.horizontal, 6)
        }
    }
}

// MARK: - Preview

extension HomeRaces.Representable.RaceFinished.Winner {
    static var mockList: [HomeRaces.Representable.RaceFinished.Winner] = {
        [
            HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Wout Van Aert", team: "TVL", time: "24:1"),
            HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Michaek Matews dfdf dfd", team: "TJA", time: "24:12"),
            HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Primoz Roglic", team: "TRBB", time: "24:12")
        ]
    }()
}

#Preview {
    ScrollView {
        VStack {
            RaceFinishedRowView(
                race: HomeRaces.Representable.RaceFinished(
                    race: "Tour du Lord",
                    raceDetails: "Stage 5 | Nikki - parakou the pinos (123 km's)",
                    winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
                    podium: HomeRaces.Representable.RaceFinished.Winner.mockList,
                    isCancel: false
                )
            )
        }
    }
//    .frame(alignment: .center)
}

import Kingfisher

struct CachedImageView: View {
    @State private var didFail: Bool = false
    
    let imageUrl: URL?
    let cornerRadius: Double
    init(imageUrl: URL?, cornerRadius: Double = 5) {
        self.imageUrl = imageUrl
        self.cornerRadius = cornerRadius
    }
    var body: some View {
        ZStack {
            if didFail {
                buildFailureImage()
            } else {
                KFImage(imageUrl)
                    .onSuccess { result in
                        print("[KINGFISHER] - Image loaded from: \(result.cacheType)")
                    }
                    .onFailure { error in
                        print("[KINGFISHER] - error: \(error.localizedDescription)")
                        didFail = true
                    }
                    .placeholder {
                        ProgressView()
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(cornerRadius)
            }
        }
    }
    
    private func buildFailureImage() -> some View {
        Image(systemName: "figure.indoor.cycle")
            .resizable()
            .scaledToFit()
            .foregroundColor(.gray)
            .scaleEffect(0.35)
    }
}
