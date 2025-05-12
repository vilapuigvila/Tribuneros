//
//  RaceInfoDetail.swift
//  Tribuneros
//
//  Created by albert vila on 26/4/25.
//

import SwiftUI

struct NextToFinishRaceDetail: View {
    let urlInfo: String
    
    @State private var raceInfo: DTO.RaceDetailInfo? = nil
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
            } catch {
                assertionFailure(error.localizedDescription)
                errorMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
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
            
            HStack(spacing: 16) {
                TribuneruText(content: "Date:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.date, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Start time:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.startTime, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Classification:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.classification, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Race Category:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.category, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Distance:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.distance, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Vertical meters:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.verticalMeters, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Departure:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.departure, style: .size14WeightRegular)
                Spacer()
            }
            HStack {
                TribuneruText(content: "Arrival:", style: .size14WeightSemiBold)
                TribuneruText(content: raceInfo.arrival, style: .size14WeightRegular)
                Spacer()
            }
            
            TribunerosDivider()
            
            TribuneruText(content: "Race Profile", style: .size14WeightSemiBold)
                .padding(.top, 8)

            if let url = raceInfo.profileURL {
                RemoteZoomableImage(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
            Spacer()
        }
    }
}

#warning("avp check it out ⚠️ -> move")
struct TribunerosDivider: View {
    let height: CGFloat
    let color: Color
    
    init(height: CGFloat = 0.5, color: Color = .gray.opacity(0.6)) {
        self.height = height
        self.color = color
    }
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
    }
}

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

import SwiftUI

struct ZoomableMainScreen<Content: View>: View {
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            content()
                .scaleEffect(scale)
                .offset(offset)
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
                .animation(.spring(), value: scale)
                .animation(.spring(), value: offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
