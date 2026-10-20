//
//  HomeRaces.WhereToWatch.BroadcasterLogo.swift
//  Tribuneros
//
//  Maps a schedule channel name to the broadcaster logo bundled in `Assets.xcassets/Broadcasters`
//  (coursedujour's logo strip). Schedule names combine channels ("Eurosport / HBO Max").
//

import Foundation

extension HomeRaces.WhereToWatch {

    enum BroadcasterLogo {

        /// One tile on the Race info card: the channel's logo, or just its name when none is bundled.
        struct Tile: Equatable, Hashable, Sendable, Identifiable {
            let name: String
            /// Asset catalog name; nil draws a name chip instead.
            let asset: String?
            var id: String { name }
        }

        /// "Sporza / VRT" → Sporza (logo) and VRT (no logo); duplicates collapse.
        static func tiles(in channelName: String) -> [Tile] {
            channelName
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { Tile(name: $0, asset: assetName(for: $0)) }
        }

        /// The asset for a single channel name, case- and accent-insensitive; nil when unknown.
        static func assetName(for channel: String) -> String? {
            lookup[fold(channel)].map { "broadcaster-\($0)" }
        }

        static var assetNames: [String] {
            Set(lookup.values).sorted().map { "broadcaster-\($0)" }
        }

        private static func fold(_ name: String) -> String {
            name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map(String.init)
                .joined()
        }

        // Folded alias → asset slug.
        private static let lookup: [String: String] = {
            let aliases: [String: [String]] = [
                "ard": [],
                "arenasport": [],
                "caracoltv": ["Caracol"],
                "clarosports": ["Claro Sport"],
                "directv": ["DirecTV Sports"],
                "eitb": [],
                "eurosport": ["Eurosport 1", "Eurosport 2"],
                "flobikes": ["FloSports", "Flo Cycling"],
                "francetv": ["France.tv", "France 2", "France 3", "France Télévisions"],
                "jsports": ["J Sports 1"],
                "lequipe": ["L’Équipe", "L'Équipe Live"],
                "m4sport": ["M4"],
                "max": ["HBO Max", "HBO"],
                "nbc": ["NBC Sports"],
                "nos": [],
                "panamsports": ["Panam Sports Channel"],
                "peacock": ["Peacock TV"],
                "proximuspickx": ["Pickx", "Proximus"],
                "rai": ["RAI Sport", "Rai 2", "RaiPlay"],
                "rsi": ["RSI La 2"],
                "rtbf": ["RTBF Auvio", "Auvio"],
                "rtp": ["RTP Play"],
                "rtr": [],
                "rts": ["RTS Sport"],
                "rtve": ["Teledeporte", "RTVE Play"],
                "rtvslovenija": ["RTV SLO"],
                "sbs": [],
                "sport5": ["Sports5", "Sport 5"],
                "sporza": [],
                "srf": ["SRF zwei"],
                "stansport": [],
                "supersport": [],
                "tg4": ["TG4 Ireland"],
                "tntsports": ["TNT Sport"],
                "tv2denmark": ["TV 2 Denmark", "TV 2 Danmark"],
                "tv2norway": ["TV 2 Norway", "TV 2 Norge"],
                "xsports": ["X-Sports"],
                "youtube": []
            ]
            var result = [String: String]()
            for (slug, names) in aliases {
                result[slug] = slug
                for name in names {
                    result[fold(name)] = slug
                }
            }
            return result
        }()
    }
}
