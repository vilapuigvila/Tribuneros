//
//  RaceInfoDetail.swift
//  Tribuneros
//
//  Created by albert vila on 26/4/25.
//

import SwiftUI

struct NextToFinishRaceDetail: View {
    let urlInfo: String
    
    @State private var showZoom = false
    @State private var raceInfo: DTO.RaceDetailInfo? = nil
    @State private var profileImage: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    
    var body: some View {
        Group {
            if let raceInfo {
                buildInfoView(raceInfo)
                    .padding()
            } else if isLoading {
                ProgressView("Loading...")
            } else {
                Text("No info available.")
            }
        }
        .background(Color.tribuneru(.greenCardBackground))
        
        .task {
            isLoading = true
            errorMessage = nil
            do {
                raceInfo = try await Requester.getNextToFinishRaceDetail(urlInfo)
                try await Requester.getInfoProfiles(urlInfo)
                guard let profileURL = raceInfo?.profileURL else {
                    return
                }
                guard let uiImage = await loadImage(profileURL) else {
                    return
                }
                profileImage = uiImage
            } catch {
                assertionFailure(error.localizedDescription)
                errorMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
        .sheet(isPresented: $showZoom) {
            NavigationView {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ZoomableMainScreen {
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                }
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
        .alert("Error", isPresented: $showAlert, actions: {
            Button("OK", role: .cancel) {
                
            }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
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
    
    private func loadImage(_ url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                return uiImage
            }
            return nil
        } catch {
            assertionFailure(error.localizedDescription)
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
}

/*
struct RemoteZoomableImage: View {
    let url: URL

    @State private var aspectRatio: CGFloat? = nil
    @State private var loadedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Group {
            if let uiImage = loadedImage {
//                GeometryReader { proxy in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { value in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 1.5
                                    lastScale = 1.5
                                }
                            }
                        }
//                        .frame(width: proxy.size.width, height: proxy.size.height)
//                }
            } else {
                ProgressView()
                    .frame(width: 100, height: 100)
                    .task {
                        await loadImage()
                    }
            }
        }
        .clipped()
    }

    func loadImage() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                loadedImage = uiImage
                aspectRatio = uiImage.size.width / uiImage.size.height
            }
        } catch {
            // handle error (show a placeholder, etc.)
        }
    }
}

struct ZoomableMainScreen<Content: View>: View {
    @State private var aspectRatio: CGFloat? = nil
    @State private var loadedImage: UIImage? = nil
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

//    let url: URL?
    let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
//            AsyncImage(url: url)
            content()
//                .aspectRatio(aspectRatio, contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
//                .clipped()
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            lastScale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 1.75
                            lastScale = 1.75
                        }
                    }
                }
                .animation(.spring(), value: scale)
                .animation(.spring(), value: offset)
//                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
*/
struct ZoomableMainScreen<Content: View>: View {
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// The content to be zoomed and panned
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content()
                    .scaledToFit()
                    .frame(
                        maxWidth: proxy.size.width * 1.0,
                        maxHeight: proxy.size.height * 1.0
                    )
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            // Pinch to zoom
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // Reset position if zoom returns to identity
                                    if lastScale <= 1 {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                },
                            // Drag to pan only when zoomed
                            DragGesture()
                                .onChanged { value in
                                    guard lastScale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    guard lastScale > 1 else {
                                        offset = .zero
                                        lastOffset = .zero
                                        return
                                    }
                                    lastOffset = offset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 1.75
                                lastScale = 1.75
                            }
                        }
                    }
                    .animation(.spring(), value: scale)
                    .animation(.spring(), value: offset)
            }
            // Fill the available screen
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
