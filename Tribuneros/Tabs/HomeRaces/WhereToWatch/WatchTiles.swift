//
//  WatchTiles.swift
//  Tribuneros
//
//  The broadcaster logo tiles on the Race info "Where to watch" card. Tiles sit on a light surface
//  (many logos are dark on transparent), a channel without a bundled logo shows its name.
//

import SwiftUI

struct WatchTiles: View {
    typealias Tile = HomeRaces.WhereToWatch.BroadcasterLogo.Tile

    static let maxVisible = 4

    static let placeholders = [
        Tile(name: "Channel 1", asset: nil),
        Tile(name: "Channel 2", asset: nil),
        Tile(name: "Channel 3", asset: nil)
    ]

    let tiles: [Tile]

    private var visible: [Tile] { Array(tiles.prefix(Self.maxVisible)) }
    private var extra: Int { max(tiles.count - Self.maxVisible, 0) }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(visible) { tile in
                tileView(tile)
                    .frame(
                        width: 64,
                        height: 40
                    )
            }
            if extra > 0 {
                TribuneruText(
                    content: "+\(extra)",
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
                .frame(minWidth: 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tileView(_ tile: Tile) -> some View {
        ZStack {
            Color.tribuneru(.white(level: 0.95))
            if let asset = tile.asset {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
            } else {
                TribuneruText(
                    content: tile.name,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporPageBackground),
                    lineLimit: 1
                )
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
