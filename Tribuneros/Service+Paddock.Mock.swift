//
//  Service+Paddock.Mock.swift
//  Tribuneros
//

#if DEBUG
import Foundation

enum PaddockMock {
    private static let base = "https://www.procyclingstats.com/rider/"

    private static func rider(
        _ name: String,
        slug: String,
        country: String
    ) -> DTO.RiderLink {
        DTO.RiderLink(
            name: name,
            url: URL(string: base + slug),
            countryCode: country
        )
    }

    /// One transfer (dated yesterday), one program update and three birthdays.
    static func paddock(now: Date = Date()) -> DTO.Paddock {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM"
        let yesterday = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: now
        ) ?? now
        return DTO.Paddock(
            transfers: [
                DTO.Transfer(
                    date: formatter.string(from: yesterday),
                    rider: rider("MOCK Transfer Rider", slug: "mock-transfer-rider", country: "it"),
                    teamName: "Ineos Grenadiers"
                )
            ],
            programUpdates: [
                DTO.ProgramUpdate(
                    timeAgo: "2h",
                    rider: rider("MOCK Program Rider", slug: "mock-program-rider", country: "si"),
                    changes: [
                        .init(isAdded: true, raceName: "Il Lombardia"),
                        .init(isAdded: false, raceName: "Tre Valli Varesine")
                    ]
                )
            ],
            birthdays: [
                DTO.Birthday(rider: rider("MOCK Birthday One", slug: "mock-birthday-one", country: "dk"), age: "31"),
                DTO.Birthday(rider: rider("MOCK Birthday Two", slug: "mock-birthday-two", country: "be"), age: "28"),
                DTO.Birthday(rider: rider("MOCK Birthday Three", slug: "mock-birthday-three", country: "es"), age: "24")
            ]
        )
    }

    static let pressLinks: [DTO.PressLink] = [
        DTO.PressLink(name: "Cycling News", url: URL(string: "https://www.cyclingnews.com")!),
        DTO.PressLink(name: "Escape Collective", url: URL(string: "https://escapecollective.com")!),
        DTO.PressLink(name: "Joan Seguidor", url: URL(string: "https://joanseguidor.com")!)
    ]

    /// Any rider URL gets a page named after its slug.
    static func riderPage(url: URL) -> DTO.PCSRiderPage {
        let name = url.lastPathComponent
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
        return DTO.PCSRiderPage(
            name: name,
            imageURL: nil,
            team: "Mock Racing Team",
            facts: [
                .init(label: "Date of birth", value: "1 January 1998"),
                .init(label: "Nationality", value: "Mockland"),
                .init(label: "Weight", value: "66 kg"),
                .init(label: "Height", value: "1.78 m")
            ]
        )
    }
}
#endif
