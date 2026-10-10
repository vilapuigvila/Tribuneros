//
//  RaceInfoDetail.swift
//  Tribuneros
//
//  Created by albert vila on 26/4/25.
//

import SwiftUI
import Alfy

struct NextToFinishRaceDetail: View {
    private typealias ImageType = DTO.StageProfile.ProfileImageType

    private struct ProfileImage: Identifiable {
        let type: ImageType
        let image: UIImage
        var id: String { "\(type.rawValue)-\(image.hashValue)" }
    }

    private struct InfoItem: Identifiable {
        let systemImage: String
        let title: String
        let value: String
        var id: String { systemImage }
    }

    let urlInfo: String
    /// The race to look up in the TV schedule; nil hides the coverage line.
    var watchKey: HomeRaces.WhereToWatch.RaceKey? = nil

    @State private var raceInfo: DTO.RaceDetailInfo? = nil
    @State private var profileImages: [ProfileImage] = []
    @State private var zoomedImageID: String?
    @State private var showZoom = false
    @State private var isLoading = true
    // The profile images download after the race info is in, so their placeholder stays until they are.
    @State private var isLoadingImages = true
    @State private var errorMessage: String?
    @State private var webPage: WebPage?
    @State private var coverage: HomeRaces.WhereToWatch.Coverage?

    private static let whereToWatchURL = URL(string: "https://coursedujour.com/")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    VStack(alignment: .leading, spacing: 20) {
                        infoPanel(.placeholder)
                        profilePlaceholderPanel
                    }
                    .redacted(reason: .placeholder)
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the race"))
                } else if let raceInfo {
                    infoPanel(raceInfo)
                    if isLoadingImages {
                        profilePlaceholderPanel
                            .redacted(reason: .placeholder)
                            .disabled(true)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(L10n.tr("Loading the race profile"))
                    } else if !profileImages.isEmpty {
                        profilePanel
                    }
                } else {
                    unavailablePanel
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(L10n.tr("Race info"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            do {
                async let raceInfoTask = Service.getNextToFinishRaceDetail(urlInfo)
                async let stageProfileTask = Service.getInfoProfiles(urlInfo)

                let (info, stageProfile) = try await (raceInfoTask, stageProfileTask)
                raceInfo = info
                isLoading = false

                await downloadProfileImages(stageProfile)
                isLoadingImages = false
            } catch {
                errorMessage = L10n.tr("Couldn’t load the race info. Check your connection and try again.")
                isLoading = false
                isLoadingImages = false
                nonFatalCrashlytics(false, error.localizedDescription)
            }
        }
        .task {
            guard Service.isCourseDuJourNativeEnabled, let watchKey else { return }
            coverage = await Service.getCourseDuJourCoverage(for: watchKey)
        }
        .sheet(isPresented: $showZoom) { zoomSheet }
        .webPage($webPage)
    }

    // MARK: - Info -

    private func infoPanel(_ info: DTO.RaceDetailInfo) -> some View {
        let items = infoItems(info)
        let tags = [info.classification, info.category].filter { !$0.isEmpty }
        return VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: L10n.tr("Race info"))
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { CXDetailTag(title: $0) }
                    }
                }

                if !info.title.isEmpty {
                    VaporCard {
                        TribuneruText(
                            content: info.title,
                            style: .vaporRaceNameNext,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 4
                        )
                    }
                }

                if !items.isEmpty {
                    VaporCard(spacing: 0) {
                        ForEach(items) { item in
                            InfoRow(item: item)
                            if item.id != items.last?.id {
                                TribunerosDivider()
                            }
                        }
                    }
                }

                watchButton
            }
        }
    }

    @ViewBuilder
    private var watchButton: some View {
        if Service.isCourseDuJourNativeEnabled {
            NavigationLink(value: Router.Destination.whereToWatch(watchKey)) {
                watchLabel(
                    trailingIcon: "chevron.right",
                    summary: coverage?.summary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("raceInfo.whereToWatch")
        } else {
            Button {
                webPage = WebPage(url: Self.whereToWatchURL)
            } label: {
                watchLabel(
                    trailingIcon: "arrow.up.right",
                    summary: nil
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("raceInfo.whereToWatch")
        }
    }

    private func watchLabel(
        trailingIcon: String,
        summary: String?
    ) -> some View {
        VaporCard {
            HStack(spacing: 10) {
                Image(systemName: "tv")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporAccent))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: L10n.tr("Where to watch"),
                        style: .vaporRaceNameResult,
                        color: .tribuneru(.vaporAccent)
                    )
                    if let summary {
                        TribuneruText(
                            content: summary,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 2
                        )
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: trailingIcon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
            }
        }
    }

    private var unavailablePanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: L10n.tr("Race info"))
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                VaporCard {
                    TribuneruText(
                        content: errorMessage ?? L10n.tr("No info available for this race yet."),
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 4
                    )
                }
                watchButton
            }
        }
    }

    private func infoItems(_ info: DTO.RaceDetailInfo) -> [InfoItem] {
        let all = [
            InfoItem(systemImage: "calendar", title: L10n.tr("Date"), value: info.date),
            InfoItem(systemImage: "clock", title: L10n.tr("Start time"), value: info.startTime),
            InfoItem(systemImage: "ruler", title: L10n.tr("Distance"), value: info.distance),
            InfoItem(
                systemImage: "mountain.2",
                title: L10n.tr("Vertical"),
                value: info.verticalMeters.allSatisfy(\.isNumber) ? L10n.tr("%@ m", info.verticalMeters) : info.verticalMeters
            ),
            InfoItem(systemImage: "flag", title: L10n.tr("Departure"), value: info.departure),
            InfoItem(systemImage: "flag.checkered", title: L10n.tr("Arrival"), value: info.arrival)
        ]
        return all.filter { !$0.value.isEmpty }
    }

    // MARK: - Profile -

    private var profilePanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            VaporSectionHeader(title: L10n.tr("Race profile"))
        } content: {
            VStack(spacing: 10) {
                ForEach(profileImages) { profile in
                    Button {
                        zoomedImageID = profile.id
                        showZoom = true
                    } label: {
                        VaporCard {
                            TribuneruText(
                                content: Self.profileTitle(profile.type).uppercased(with: L10n.locale),
                                style: .vaporGroupLabel,
                                color: .tribuneru(.vaporTextSecondary)
                            )
                            Image(uiImage: profile.image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var profilePlaceholderPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            VaporSectionHeader(title: L10n.tr("Race profile"))
        } content: {
            VaporCard {
                TribuneruText(
                    content: L10n.tr("PROFILE"),
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporTextSecondary)
                )
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.tribuneru(.vaporTextSecondary))
                    .frame(height: 200)
            }
        }
    }

    private var zoomSheet: some View {
        NavigationView {
            ZStack {
                Color.tribuneru(.vaporPageBackground).ignoresSafeArea()
                TabView(selection: $zoomedImageID) {
                    ForEach(profileImages) { profile in
                        ZoomableMainScreen {
                            Image(uiImage: profile.image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .tag(Optional(profile.id))
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .automatic))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showZoom = false
                    } label: {
                        TribuneruText(
                            content: L10n.tr("Done"),
                            style: .vaporRaceNameResult,
                            color: .tribuneru(.vaporAccent)
                        )
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Images -

    /// The title of a PCS profile image, for display. The raw values stay in `DTO.StageProfile`.
    private static func profileTitle(_ type: ImageType) -> String {
        switch type {
        case .profile: L10n.tr("Profile")
        case .finishProfile: L10n.tr("Finish profile")
        case .climb: L10n.tr("Climb")
        case .map: L10n.tr("Map")
        case .localCircut: L10n.tr("Local circuit")
        case .none: L10n.tr("none")
        }
    }

    private func downloadProfileImages(_ stageProfile: [DTO.StageProfile]) async {
        let order: [ImageType] = [.profile, .finishProfile, .climb, .map, .localCircut]
        let wanted: [(ImageType, URL)] = order.flatMap { type in
            stageProfile
                .filter { $0.type == type }
                .compactMap { URL(string: $0.url).map { (type, $0) } }
        }
        guard !wanted.isEmpty else { return }

        var loaded: [Int: ProfileImage] = [:]
        await withTaskGroup(of: (Int, ProfileImage?).self) { group in
            for (index, item) in wanted.enumerated() {
                group.addTask {
                    (index, await loadImage(item.1, type: item.0))
                }
            }
            for await (index, image) in group {
                loaded[index] = image
            }
        }
        // Keeps the fixed type order regardless of which download finished first.
        profileImages = loaded.keys.sorted().compactMap { loaded[$0] }
    }

    private func loadImage(_ url: URL, type: ImageType) async -> ProfileImage? {
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .headers(Service.pcsImageHeaders(for: url))
                .ttl(86400 * 7) // 1 week
                .cacheControlBehavior(.ignoreServer)
                .send()
            return UIImage(data: data).map { ProfileImage(type: type, image: $0) }
        } catch {
            if !Service.isOffline(error) {
                nonFatalCrashlytics(false, error.localizedDescription)
            }
            return nil
        }
    }

    private struct InfoRow: View {
        let item: InfoItem

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                    .frame(width: 18)
                TribuneruText(
                    content: item.title,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary)
                )
                .frame(width: 72, alignment: .leading)
                TribuneruText(
                    content: item.value,
                    style: .vaporRaceNameResult,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
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

extension DTO.RaceDetailInfo {

    /// A stand-in shaped like a real race, drawn redacted while the race loads.
    static let placeholder = DTO.RaceDetailInfo( // l10n:ignore
        title: "Race name placeholder", // l10n:ignore
        date: "00-00-0000",
        startTime: "00:00",
        classification: "Classification",
        category: "Category",
        distance: "000 km",
        departure: "Departure town",
        arrival: "Arrival town",
        verticalMeters: "0000",
        profileURL: nil
    )
}
