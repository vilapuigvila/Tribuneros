//
//  RaceFinishedCardView.swift
//  Tribuneros
//
//  Created by albert vila on 11/3/25.
//

import SwiftUI

struct RaceFinishedCardView: View {
    private typealias Podium = HomeRaces.Representable.RaceFinished.Winner
    @State private var showPodium: Bool = UserSettings.spoilerModeResultsYesterday ?? false
    
    let title: String
    let races: [HomeRaces.Representable.RaceFinished]
    let contentWidth: CGFloat
    let spoilerModeAction: () -> Void
    let showResultsAction: () -> Void
    
    var animationDuration: TimeInterval {
        0.5 + (Double(races.count / 2) * 0.05)
    }
    var body: some View {
        VStack(/*alignment: .center,*/ spacing: Sizes.spacingVerticalRace) {
            HeaderRaceCardView(
                title: title,
                spoilerModeAction: spoilerModeAction,
                showResultsAction: {
                    withAnimation(.easeInOut(duration: animationDuration)) {
                        showPodium.toggle()
                    }
                }
            )
            if showPodium {
                ForEach(races) { race in
                    HStack(/*alignment: .center,*/  spacing: 0) {
                        AsyncImageView(url: race.winnerImgURL, cornerRadius: 4)
                            .frame(width: Sizes.imgWidth)
                        //                            .frame(height: 112*0.41)
                            .padding(.leading, Sizes.leadingImg)
                            .scaleEffect(Sizes.scaleEffect)
                        
                        VStack(alignment: .leading, spacing: Sizes.spacingVerticalLabelsInRace) {
                            Text(race.race)
                                .lineLimit(1)
                                .font(.system(size: 14, weight: .heavy, design: .default))
                                .debugBackground()
                            
                            Text(race.raceDetails)
                                .lineLimit(1)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.top, -4)
                            //                                .fixedSize(horizontal: false, vertical: true)
                                .debugBackground()
                            
                            ForEach(race.podium) { podium in
                                HStack(alignment: .top, spacing: 2) {
                                    buildPositionAndFlag(
                                        position: podium.position,
                                        countryCode: podium.countryCode
                                    )
                                    GeometryReader { geo in
                                        buildPodiumInfo(podium: podium, width: geo.size.width)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .padding(.leading, Sizes.leadingContainerInfo)
                        .debugBackground(color: .red, opacity: 0.5)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
//                    .scaleEffect(y: showPodium ? 1 : 0, anchor: .top)
//                    .opacity(showPodium ? 1 : 0)
//                    .animation(.easeInOut(duration: 1.4), value: showPodium)
//                    .transition(
//                        .opacity
//                            .combined(with: .scale(scale: 1.0, anchor: .top))
//                    )
//                    .animation(.easeInOut(duration: 0.9), value: showPodium)
                    
                    Divider()
                }
                .debugBackground(color: .purple, opacity: 0.2)
                .scaleEffect(y: showPodium ? 1 : 0, anchor: .top)
//                .opacity(showPodium ? 1 : 0)
//                .animation(.easeInOut(duration: 1.4), value: showPodium)
            }
        }
    }
    
    private func buildPodiumInfo(podium: Podium, width: CGFloat) -> some View {
        HStack {
            /// Name
            Text(podium.name)
                .lineLimit(1)
                .font(.system(size: Sizes.fontSizeLabelsInfo, weight: .bold, design: .monospaced))
                .frame(width: width * (podium.team.isEmpty ? 0.7 : 0.65), alignment: .leading)
                .debugBackground()
            
            Spacer()
            
            /// Team
            if !podium.team.isEmpty {
                Text(podium.team)
                    .lineLimit(1)
                    .font(.system(size: Sizes.fontSizeLabelsInfo-1, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .debugBackground()
                
                Spacer()
            }
            
            /// Time
            Text(podium.time)
                .lineLimit(1)
                .font(.system(size: Sizes.fontSizeLabelsInfo-1, weight: .regular, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: podium.team.isEmpty ? .trailing : .leading)
                .debugBackground()
        }
    }
    
    private func buildPositionAndFlag(position: String, countryCode: String) -> some View {
        HStack(spacing: 2) {
            Text(position)
                .lineLimit(1)
                .font(.system(size: Sizes.fontSizeLabelsInfo, weight: .regular, design: .monospaced))
                .debugBackground(color: .red, opacity: 0.3)
            
            AsyncImageView(url: URL(string: "https://flagcdn.com/w40/\(countryCode).png")!)
                .frame(width: Sizes.flagWidth, height: 9)
                .padding(.horizontal, 6)
                .debugBackground()
        }
    }
    
    private enum Sizes {
        static let debugOpacity: Double = 0.1
        
        static let spacingVerticalLabelsInRace: CGFloat = 8
        static let spacingVerticalRace: CGFloat = 8
        static let spacingHorizontalLabels: CGFloat = 8
        static let leadingImg: CGFloat = 8
        static let leadingContainerInfo: CGFloat = 8
        static let fontSizeLabelsInfo: CGFloat = 13
        static let scaleEffect: Double = 1.0
        static let imgWidth: Double = 50
        static let flagWidth: Double = 12
        
        private static func totalWidth(_ parentWidth: CGFloat) -> CGFloat {
            parentWidth - leadingImg - imgWidth - leadingContainerInfo - flagWidth - (2*4) // 3 o 4
        }
        
        static func positionWith(_ parentWidth: CGFloat) -> CGFloat {
            let _totalWidth: CGFloat = totalWidth(parentWidth)
            return _totalWidth * 0.03
        }
        static func racerWith(_ parentWidth: CGFloat) -> CGFloat {
            let _totalWidth: CGFloat = totalWidth(parentWidth)
            return _totalWidth * 0.6
        }
        static func teamWith(_ parentWidth: CGFloat) -> CGFloat {
            let _totalWidth: CGFloat = totalWidth(parentWidth)
            return _totalWidth * 0.15
        }
        static func timeWith(_ parentWidth: CGFloat) -> CGFloat {
            let _totalWidth: CGFloat = totalWidth(parentWidth)
            return _totalWidth * 0.15
        }
    }
}

#Preview {
    let racesITT = [
        HomeRaces.Representable.RaceFinished(race: "Volta Catalunya", raceDetails: "General classification", winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg"), podium: [
            HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Visma | Lease a bike", team: "", time: "24:12"),
            HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Team Jayco Alula", team: "", time: "24:12"),
            HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Red Bull - Bora - Hansgrohe", team: "", time: "24:12")
        ], isCancel: false)
    ]
    
    let _races = [
        HomeRaces.Representable.RaceFinished(
            race: "Volta Ciclista a Catalunya (2.UWT)",
            raceDetails: "no info available..",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg"), podium: [
            HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Wout Van Aert", team: "TVL", time: "24:1"),
            HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Michaek Matews dfdf dfd", team: "TJA", time: "24:12"),
            HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Primoz Roglic", team: "TRBB", time: "24:12")
        ], isCancel: false),
        HomeRaces.Representable.RaceFinished(
            race: "Volta Catalunya",
            raceDetails: "Stage 2",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg"),
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Visma | Lease a bike", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Team Jayco Alula", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Red Bull - Bora - Hansgrohe", team: "", time: "24:12")
        ], isCancel: false)
    ]
    
    ScrollView {
        RaceFinishedCardView(title: "Results Yesterday", races: _races, contentWidth: 440) {
//            let _ = print("avvp - ")
//            UserSettings.spoilerModeResultsYesterday?.toggle()
        } showResultsAction: {
            
        }
//        .frame(alignment: .center)
        .background(Color.green.opacity(0.2))
        .cornerRadius(8)
    }
    .frame(height: 450, alignment: .center)
    .debugBackground(color: .gray, opacity: 0.05)
    .padding()

}


struct DebugBackgroundModifier: ViewModifier {
    var color: Color
    var opacity: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.isPreview {
            content.background(color.opacity(opacity))
        } else if ProcessInfo.processInfo.environment["DEBUG_BACKGROUND"] != nil {
            content.background(color.opacity(opacity))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    func debugBackground(color: Color = .yellow, opacity: Double = 0.1) -> some View {
        self.modifier(DebugBackgroundModifier(color: color, opacity: opacity))
    }
}

extension ProcessInfo {
    var isPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "0"
    }
}
