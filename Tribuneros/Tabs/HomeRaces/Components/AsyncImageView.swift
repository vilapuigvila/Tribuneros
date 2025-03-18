//
//  AsyncImageView.swift
//  Tribuneros
//
//  Created by albert vila on 11/3/25.
//

import SwiftUI

struct AsyncImageView: View {
    @State private var timedOut: Bool = false
    @State private var opacity: Double = 0.3
    @State private var opacitySuccessImage: Double = 0
    @State private var isAnimating: Bool = false
    @State private var image: Image?
    
    let url: URL?
    private(set) var cornerRadius: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.gray.opacity(0.2)
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        if timedOut {
                            buildFailureImage()
                        } else {
                            buildLoadingImage(phase)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .opacity(opacitySuccessImage)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.7)) {
                                    opacitySuccessImage = 1.0
                                }
                            }
                    case .failure:
                        buildFailureImage()
                    @unknown default:
                        buildFailureImage()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .cornerRadius(cornerRadius)
        }
    }
    private func buildImage(_ image: Image) -> some View {
        self.image = image
        return Group {
            EmptyView()
        }
    }
    private func buildFailureImage() -> some View {
        Image(systemName: "figure.indoor.cycle")
            .resizable()
            .scaledToFit()
            .foregroundColor(.gray)
            .foregroundColor(.gray)
            .scaleEffect(0.35)
    }
    
    private func buildLoadingImage(_ phase: AsyncImagePhase) -> some View {
        Image(systemName: "figure.outdoor.cycle") // Another system icon
            .resizable()
            .scaledToFit()
            .foregroundColor(.gray)
            .opacity(opacity)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: opacity)
            .offset(x: isAnimating ? 7 : -7)
            .scaleEffect(0.35)
            .animation(
                .easeInOut(duration: 0.8) .repeatForever(autoreverses: true), value: isAnimating
            )
            .onAppear {
                opacity = 1.0
                isAnimating = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if case .empty = phase {
                        timedOut = true
                    }
                }
            }
    }
}

#Preview {
    VStack(spacing: 0) {
        HStack(spacing: 16) {
            AsyncImageView(
                url: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!
            )
            .frame(width: 75)

            Text("Loading...")
            Spacer()
        }
        .padding()
    }
    .frame(maxWidth: .infinity)
    .frame(height: 140)
    .background(.green.opacity(0.2))
    .padding()
    
    Spacer()
}
