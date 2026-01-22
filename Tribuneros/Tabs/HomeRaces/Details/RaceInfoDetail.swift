//
//  RaceInfoDetail.swift
//  Tribuneros
//
//  Created by albert vila on 26/4/25.
//

import SwiftUI

struct NextToFinishRaceDetail: View {
    private typealias ImageType = DTO.StageProfile.ProfileImageType
    let urlInfo: String
    
    @State private var showZoom = false
    @State private var raceInfo: DTO.RaceDetailInfo? = nil
    @State private var profileImage: UIImage? = nil
    @State private var profileImages: [(ImageType, UIImage)] = []
    @State private var stageProfile: [DTO.StageProfile] = []
    @State private var isLoading = false
    
    @State private var showLoader = false

    @State private var activeAlert: ActiveAlert?
    
    init(
        urlInfo: String,
        raceInfo: DTO.RaceDetailInfo? = nil,
        stageProfile: [DTO.StageProfile] = []
    ) {
        self.urlInfo = urlInfo
        _raceInfo = State(initialValue: raceInfo)
        _stageProfile = State(initialValue: stageProfile)
    }
    
    var body: some View {
        ZStack {
            Group {
                if let raceInfo {
                    buildInfoView(raceInfo)
                        .padding()
                        .transition(.opacity)
                } else if showLoader {
                    CyclistLoaderWithIcon(withAnimating: true)
                        .background(.black)
                        .transition(.opacity)
                    
                } else {
                    EmptyView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.75), value: (raceInfo != nil || isLoading))
        .background(Color.tribuneru(.greenCardBackground))
        .task {
            guard !ProcessInfo.processInfo.isPreview else { return }
            
            showLoader = false
            isLoading = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if isLoading {
                    showLoader = true
                }
            }
            do {
                async let raceInfoTask = Requester.getNextToFinishRaceDetail(urlInfo)
                async let stageProfileTask = Requester.getInfoProfiles(urlInfo)

                let (_raceInfo, _stageProfile) = try await (raceInfoTask, stageProfileTask)
                raceInfo = _raceInfo
                stageProfile = _stageProfile
                
                isLoading = false
                
                await downloadAllProfilesImages()

            } catch {
                activeAlert = .error(error.localizedDescription)
                isLoading = false
                nonFatalCrashlytics(false, error.localizedDescription)
            }
        }
        .sheet(isPresented: $showZoom) {
            NavigationView {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if !profileImages.isEmpty {
                        TabView {
                            if let image = profileImage {
                                ZoomableMainScreen {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.black)
                                }
                            }

                            let climbs = profileImages.filter { $0.0 == .climb }
                            ForEach(Array(climbs.enumerated()), id: \.offset) { _, climb in
                                ZoomableMainScreen {
                                    Image(uiImage: climb.1)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.black)
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .indexViewStyle(.page(backgroundDisplayMode: .automatic))
                    } else {
                        EmptyView()
                    }
                }
                .padding(.top, 4)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showZoom = false }
                            .bold()
                            .foregroundColor(.white)
                    }
                }
            }
//           .presentationDetents([.fraction(0.9)])
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .error(let message):
                return Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .cancel(Text("OK"))
                )
            case .debug(let message):
                return Alert(
                    title: Text("DEBUG ERROR"),
                    message: Text(message),
                    dismissButton: .cancel(Text("OK"))
                )
            }
        }
    }
    
    private func buildInfoView(_ raceInfo: DTO.RaceDetailInfo) -> some View {
        VStack(spacing: 12) {
            TribuneruText(content: raceInfo.title, style: .size16WeightBold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TribunerosDivider()
                .padding(.vertical, 4)
            
            ForEach(rows, id: \.title) { row in
                HStack(spacing: 16) {
                    TribuneruText(content: "\(row.title):", style: .size14WeightSemiBold)
                        .minimumScaleFactor(0.6)
                        .frame(width: UIScreen.main.bounds.width * 0.4, alignment: .leading)
                        .debugBackground()
                    
                    TribuneruText(content: row.content ?? "–", style: .size14WeightRegular)
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
            }
            TribunerosDivider()
            
            TribuneruText(content: "Race Profile", style: .size14WeightSemiBold)
                .padding(.top, 8)

            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(8)
                    .onTapGesture {
                        showZoom = true
                    }
            }
            Spacer()
        }
    }
    
    private func downloadAllProfilesImages() async {
        let types: [ImageType] = [.climb, .profile, .profile, .finishProfile]

        let allURLs: [(ImageType, URL)] = types.flatMap { type in
            stageProfile
                .filter { $0.type == type }
                .compactMap { URL(string: $0.url).map { (type, $0) } }
        }
        
        guard !allURLs.isEmpty else {
            activeAlert = .debug("No profile URLs found")
            return
        }

        var images: [(ImageType, UIImage)] = []
        images.reserveCapacity(allURLs.count)

        await withTaskGroup(of: (ImageType, UIImage)?.self) { group in
            for tuple in allURLs {
                group.addTask {
                    await loadImage(tuple.1, key: tuple.0)
                }
            }
            for await image in group {
                if let img = image {
                    images.append(img)
                }
            }
        }
        profileImage = images.first(where: { $0.0 == .profile })?.1
        profileImages = images
    }
    
    private func loadImage(_ url: URL, key: ImageType) async -> (ImageType, UIImage)? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                return (key, uiImage)
            }
            return nil
        } catch {
            nonFatalCrashlytics(false, error.localizedDescription)
            return nil
        }
    }
    
    private var rows: [(title: String, content: String?)] {
        [
            ("Date",           raceInfo?.date),
            ("Start Time",     raceInfo?.startTime),
            ("Classification", raceInfo?.classification),
            ("Category",       raceInfo?.category),
            ("Distance",       raceInfo?.distance),
            ("Departure",      raceInfo?.departure),
            ("Arrival",        raceInfo?.arrival),
            ("Vertical Meters",raceInfo?.verticalMeters)
        ]
    }
    
    private enum ActiveAlert: Identifiable {
        case error(String)
        case debug(String)
        
        var id: String {
            switch self {
            case .error: return "error"
            case .debug: return "debug"
            }
        }
    }
}

// MARK: - Zoom View -

struct ZoomableMainScreen<Content: View>: View {
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        GeometryReader { proxy in
            // Gestures
            let magnify = MagnificationGesture()
                .onChanged { value in
                    scale = max(1, lastScale * value)
                }
                .onEnded { _ in
                    lastScale = max(1, scale)
                    if lastScale == 1 {
                        offset = .zero
                        lastOffset = .zero
                    }
                }

            let pan = DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard lastScale > 1 else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    if lastScale > 1 {
                        lastOffset = offset
                    } else {
                        offset = .zero
                        lastOffset = .zero
                    }
                }

            content()
                .scaledToFit()
                .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .contentShape(Rectangle())              // full hit area
                .gesture(magnify)                       // always allow pinch
                // Only enable drag gesture when zoomed; otherwise let TabView swipe
                .simultaneousGesture(pan, including: lastScale > 1 ? .all : .none)
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if lastScale > 1 {
                            scale = 1; lastScale = 1
                            offset = .zero; lastOffset = .zero
                        } else {
                            scale = 1.75; lastScale = 1.75
                        }
                    }
                }
                .animation(.spring(), value: scale)
                .animation(.spring(), value: offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}


struct CyclistLoaderWithIcon: View {
    @State private var rotation: Double = 0
    
    let withAnimating: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                .frame(width: 80, height: 80)

            Image(systemName: "bicycle")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(withAnimating ? rotation : 0))
        }
        .onAppear {
            if withAnimating {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

#if DEBUG
var raceInfo: DTO.RaceDetailInfo? = DTO.RaceDetailInfo(
    title: "Tour du Lord — Stage 5",
    date: "Apr 26, 2025",
    startTime: "12:15",
    classification: "Stage Race",
    category: "UCI",
    distance: "185.6 km",
    departure: "Nice",
    arrival: "Col du Something",
    verticalMeters: "3,450 m",
    profileURL: nil
)

var stageProfile: [DTO.StageProfile] = [
    DTO.StageProfile(type: .profile, url: "https://example.com/profile.png"),
    DTO.StageProfile(type: .climb, url: "https://example.com/climb.png")
]

#Preview("Loaded") {
    NextToFinishRaceDetail(
        urlInfo: "preview://race-detail",
        raceInfo: raceInfo,
        stageProfile: stageProfile
    )
}
#endif
