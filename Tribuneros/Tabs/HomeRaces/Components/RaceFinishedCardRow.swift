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
    enum Presentation {
        case fitted
        case racePhoto
    }

    @State private var didFail: Bool = false

    let imageUrl: URL?
    let cornerRadius: Double
    let presentation: Presentation

    init(
        imageUrl: URL?,
        cornerRadius: Double = 5,
        presentation: Presentation = .fitted
    ) {
        self.imageUrl = imageUrl
        self.cornerRadius = cornerRadius
        self.presentation = presentation
    }

    var body: some View {
        ZStack {
            if didFail || imageUrl == nil {
                buildFailureImage()
            } else {
                KFImage(imageUrl)
                    .requestModifier { request in
                        Service.addPCSImageHeaders(to: &request)
                    }
                    .onSuccess { result in
                        print("[KINGFISHER] - Image loaded from: \(result.cacheType)")
                    }
                    .onFailure { error in
                        print("[KINGFISHER] - error: \(error.localizedDescription)")
                        didFail = true
                    }
                    .placeholder {
                        buildPlaceholder()
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .aspectRatio(contentMode: presentation == .racePhoto ? .fill : .fit)
                    .cornerRadius(cornerRadius)
            }
        }
        .onChange(of: imageUrl) {
            didFail = false
        }
    }

    @ViewBuilder
    private func buildPlaceholder() -> some View {
        switch presentation {
        case .fitted:
            ProgressView()
        case .racePhoto:
            RaceArtView.fallback
        }
    }

    @ViewBuilder
    private func buildFailureImage() -> some View {
        switch presentation {
        case .fitted:
            Image(systemName: "figure.indoor.cycle")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
                .scaleEffect(0.35)
        case .racePhoto:
            RaceArtView.fallback
        }
    }
}

struct WinnerPhoto: View {
    let url: URL?
    let size: CGSize
    var isHiddenBySpoiler = false

    var body: some View {
        if isHiddenBySpoiler {
            Color.clear
                .frame(
                    width: size.width,
                    height: size.height
                )
        } else {
            photo
        }
    }

    private var photo: some View {
        CachedImageView(
            imageUrl: url,
            cornerRadius: 0,
            presentation: .racePhoto
        )
        .frame(
            width: size.width,
            height: size.height,
            alignment: .top
        )
        .clipped()
    }
}

extension HomeRaces.Representable.RaceFinished {
    /// Built from placeholder values, so nothing real reaches the view tree, photo loader or VoiceOver.
    func shown(_ visibility: HomeRaces.ResultVisibility) -> Self {
        let blank = HomeRaces.Representable.placeholderResults[0]
        switch visibility {
        case .shown:
            return self
        case .hidden:
            return Self(
                race: race,
                raceDetails: raceDetails.isEmpty ? "" : "Race details placeholder",
                winnerImgURL: nil,
                podium: blank.podium,
                isCancel: isCancel
            )
        case .placeholder:
            return blank
        }
    }
}

extension View {
    /// Redacts a result card's values; its title stays readable when hidden behind the spoiler.
    @ViewBuilder
    func redactedResult(
        _ visibility: HomeRaces.ResultVisibility,
        title: String
    ) -> some View {
        if visibility == .shown {
            self
        } else {
            redacted(reason: .placeholder)
                .accessibilityHidden(true)
                .overlay {
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel(visibility == .hidden ? title : "Loading results")
                }
        }
    }
}

extension View {
    func resultGestures(
        _ visibility: HomeRaces.ResultVisibility,
        open: @escaping () -> Void,
        toggle: @escaping () -> Void
    ) -> some View {
        modifier(
            ResultTapModifier(
                visibility: visibility,
                open: open,
                toggle: toggle
            )
        )
    }
}

/// Own double-tap window (0.5s, native is 0.35s) so UI-test drivers whose taps land ~0.35s apart still count.
private struct ResultTapModifier: ViewModifier {
    private static let window: TimeInterval = 0.5

    let visibility: HomeRaces.ResultVisibility
    let open: () -> Void
    let toggle: () -> Void

    @State private var lastTap: Date?
    @State private var pendingOpen: Task<Void, Never>?

    @ViewBuilder
    func body(content: Content) -> some View {
        switch visibility {
        case .placeholder:
            content
        case .hidden:
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: handleTap)
                .accessibilityAction(named: "Show results", toggle)
        case .shown:
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: handleTap)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Hide results", toggle)
        }
    }

    private func handleTap() {
        let now = Date()
        if let lastTap, now.timeIntervalSince(lastTap) < Self.window {
            self.lastTap = nil
            pendingOpen?.cancel()
            toggle()
            return
        }
        lastTap = now
        guard visibility == .shown else { return }
        pendingOpen = Task {
            try? await Task.sleep(for: .seconds(Self.window))
            guard !Task.isCancelled else { return }
            open()
        }
    }
}

extension View {
    /// Drawn outside the redacted, combined card so it stays unredacted and visible to accessibility tools.
    @ViewBuilder
    func spoilerArt(
        _ visibility: HomeRaces.ResultVisibility,
        size: CGSize,
        alignment: Alignment,
        identifier: String?
    ) -> some View {
        if visibility == .hidden {
            overlay(alignment: alignment) {
                RaceArtView(art: .spoiler)
                    .frame(
                        width: size.width,
                        height: size.height
                    )
                    .transition(.opacity)
                    .accessibilityElement()
                    .accessibilityLabel("Result hidden")
                    .accessibilityIdentifier(identifier ?? "spoilerArt")
            }
        } else {
            self
        }
    }
}

struct SpoilerCrossfade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSpoilerModeOn: Bool

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: isSpoilerModeOn
        )
    }
}

extension View {
    func spoilerCrossfade(_ isSpoilerModeOn: Bool) -> some View {
        modifier(SpoilerCrossfade(isSpoilerModeOn: isSpoilerModeOn))
    }
}

extension View {
    @ViewBuilder
    func unredacted(if condition: Bool) -> some View {
        if condition {
            unredacted()
        } else {
            self
        }
    }
}
