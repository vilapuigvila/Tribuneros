//
//  CXRaces.Placeholders.swift
//  Tribuneros
//
//  Stand-in data shaped like real content, drawn redacted by the CX screens while they load
//  (the same pattern as `Paddock.Section.placeholders`). Image URLs stay `nil` so a placeholder
//  never hits the network.
//

import Foundation

extension CXRaces.Representable {

    /// A calendar of three upcoming races, one latest race with two podium categories and one
    /// standings ranking: what the CX Zone tab shows once loaded.
    static let placeholders = CXRaces.Representable(
        calendarEvents: (1...3).map { index in
            .init(
                date: "0\(index)-01-2099",
                race: "Race name placeholder",
                raceClass: "C1",
                flagURL: nil,
                winnerName: "",
                isCancelled: false,
                raceID: nil,
                raceSlug: nil,
                raceURL: nil,
                resultsURL: nil,
                videoURL: nil,
                websiteURL: nil,
                raceCountry: nil,
                winnerURL: nil,
                winnerCountry: nil,
                winnerFlagURL: nil
            )
        },
        races: .init(
            sections: [
                .init(
                    title: "Latest results",
                    races: [
                        .init(
                            title: "Race name placeholder",
                            country: "Country",
                            countryFlagURL: nil,
                            date: "0 Month 0000",
                            location: "Location, Country",
                            raceURL: nil,
                            categories: ["Men Elite", "Women Elite"].map { title in
                                .init(
                                    title: title,
                                    categoryURL: nil,
                                    winnerImageURL: nil,
                                    podium: (1...3).map { position in
                                        .init(
                                            position: position,
                                            rider: "RIDER Name",
                                            riderURL: nil,
                                            country: "Country",
                                            countryFlagURL: nil,
                                            time: "00:00"
                                        )
                                    }
                                )
                            }
                        )
                    ]
                )
            ]
        ),
        standings: .init(
            items: [
                .init(
                    title: "Ranking title placeholder",
                    url: nil,
                    logoURL: nil,
                    categories: [
                        .init(
                            title: "Men Elite",
                            url: nil,
                            leaders: (1...5).map { position in
                                .init(
                                    position: position,
                                    rider: "RIDER Name",
                                    riderURL: nil,
                                    countryFlagURL: nil,
                                    points: "0000"
                                )
                            },
                            leaderImageURL: nil
                        )
                    ]
                )
            ]
        )
    )
}

extension DTO.CX24Homepage.CategoryResult {

    /// Ten results rows, the length of the calendar detail's top 10.
    static let placeholders: [DTO.CX24Homepage.CategoryResult] = (1...10).map { position in
        .init(
            position: "\(position)",
            rider: "RIDER Name",
            age: "00",
            team: "Team name placeholder",
            time: "0:00",
            countryFlagURL: nil,
            raceVideosURL: nil
        )
    }
}

extension DTO.CXRacePage.PastWinner {

    static let placeholders: [DTO.CXRacePage.PastWinner] = (1...6).map { _ in
        .init(
            year: "0000",
            rider: "RIDER Name",
            riderURL: nil,
            countryFlagURL: nil,
            resultsURL: nil
        )
    }
}

extension DTO.CXRiderPage.Fact {

    static let placeholders: [DTO.CXRiderPage.Fact] = [
        .init(
            label: "Date of birth",
            value: "00 Month 0000"
        ),
        .init(
            label: "Nationality",
            value: "Country"
        ),
        .init(
            label: "Team",
            value: "Team name placeholder"
        ),
        .init(
            label: "Height",
            value: "0.00 m"
        ),
        .init(
            label: "Weight",
            value: "00 kg"
        )
    ]
}

extension DTO.CXRiderPage.Result {

    /// A placeholder link keeps the row's chevron, so the row has its real shape.
    static let placeholders: [DTO.CXRiderPage.Result] = (1...5).map { _ in
        .init(
            date: "00-00-0000",
            race: "Race name placeholder",
            position: "0",
            raceURL: URL(string: "https://placeholder.invalid")
        )
    }
}
