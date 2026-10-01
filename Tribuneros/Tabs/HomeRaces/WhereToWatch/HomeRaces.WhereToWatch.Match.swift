//
//  HomeRaces.WhereToWatch.Match.swift
//  Tribuneros
//
//  Finds the race a Today Races row opened in coursedujour's schedule. The two sites name races
//  differently ("Le Tour de Langkawi - S5" vs "Petronas Le Tour de Langkawi — Stage 5"), so a
//  schedule row is scored on name words, stage, class, gender and age instead of compared as text.
//

import Foundation

extension HomeRaces.WhereToWatch {

    /// The PCS race to find in the schedule, built from its Today Races row.
    struct RaceKey: Hashable, Sendable {
        /// "Le Tour de Langkawi", without the " - S5" stage suffix.
        let name: String
        /// "5"; nil for a one-day race.
        let stage: String?
        /// "2.Pro"
        let raceClass: String
        /// PCS category: "ME", "WE", "MU", "WJ"…
        let category: String
        /// The race day on the schedule's calendar (Central European time), "yyyy-MM-dd".
        let date: String

        /// "Le Tour de Langkawi · Stage 5"
        var title: String {
            stage.map { "\(name) · \(HomeRaces.Stage.label($0))" } ?? name
        }
    }

    /// What the schedule says about the opened race, for the Race info button.
    enum Coverage: Equatable, Sendable {
        case channels([String])
        case noBroadcast
        case notListed

        /// "FloBikes · Eurosport / HBO Max"
        var summary: String {
            switch self {
            case .channels(let names):
                let shown = names.prefix(3).joined(separator: " · ")
                return names.count > 3 ? "\(shown) +\(names.count - 3)" : shown
            case .noBroadcast:
                return "Listed, no broadcast yet"
            case .notListed:
                return "Not in the TV listings"
            }
        }
    }

    static let scheduleTimeZone = TimeZone(identifier: "Europe/Paris")!

    private enum Gender {
        case men, women
    }

    private enum Age {
        case elite, u23, junior
    }

    /// The best-scoring schedule row for `key`, or nil when none is close enough or two tie.
    static func match(
        _ key: RaceKey,
        in page: DTO.CourseDuJourPage
    ) -> DTO.CourseDuJourPage.Race? {
        let scored = page.sections
            .flatMap(\.races)
            .compactMap { race in score(race, for: key).map { (race, $0) } }
            .sorted { $0.1 > $1.1 }
        guard let best = scored.first else { return nil }
        if scored.count > 1, scored[1].1 == best.1 {
            return nil
        }
        return best.0
    }

    static func coverage(
        for key: RaceKey,
        in page: DTO.CourseDuJourPage
    ) -> Coverage {
        guard let race = match(key, in: page) else { return .notListed }
        var seen = Set<String>()
        let names = race.broadcasters.map(\.name).filter { seen.insert($0).inserted }
        return names.isEmpty ? .noBroadcast : .channels(names)
    }

    /// nil rules the row out; otherwise higher is closer.
    private static func score(
        _ race: DTO.CourseDuJourPage.Race,
        for key: RaceKey
    ) -> Double? {
        let wanted = nameWords(key.name)
        let candidate = nameWords(race.name)
        let overlap = wanted.intersection(candidate).count
        guard let smaller = [wanted.count, candidate.count].min(), smaller > 0 else { return nil }
        let isSingleWordMatch = wanted.count == 1 && candidate.count == 1 && overlap == 1
        let nameScore = Double(overlap) / Double(smaller)
        guard isSingleWordMatch || (overlap >= 2 && nameScore >= 0.66) else { return nil }

        var score = nameScore
        let raceStage = stageNumber(race.stage)
        if let wantedStage = key.stage, let raceStage {
            guard wantedStage.lowercased() == raceStage else { return nil }
            score += 0.2
        }

        let facetsText = [race.name, race.stage ?? "", race.category].joined(separator: " ")
        let (wantedGender, wantedAge) = facets(category: key.category)
        if let wantedGender, let raceGender = gender(in: facetsText) {
            guard wantedGender == raceGender else { return nil }
        }
        if let wantedAge, let raceAge = age(in: facetsText) {
            guard wantedAge == raceAge else { return nil }
            score += 0.1
        }

        let raceClass = race.category
            .components(separatedBy: "(")
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !key.raceClass.isEmpty, raceClass.caseInsensitiveCompare(key.raceClass) == .orderedSame {
            score += 0.3
        }
        return score
    }

    private static let fillerWords: Set<String> = [
        "a", "al", "and", "cycliste", "d", "da", "de", "del", "della", "delle", "dell", "des", "di",
        "du", "el", "en", "et", "il", "l", "la", "le", "les", "of", "the", "y"
    ]

    private static func words(_ text: String) -> [String] {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Folded name words without years or filler; "GP" counts as "Grand Prix", "Under 23" as "U23".
    private static func nameWords(_ name: String) -> Set<String> {
        var result = Set<String>()
        let all = words(name)
        var index = all.startIndex
        while index < all.endIndex {
            let word = all[index]
            if word == "under", all.indices.contains(index + 1), all[index + 1] == "23" {
                result.insert("u23")
                index += 2
                continue
            }
            if word == "gp" {
                result.formUnion(["grand", "prix"])
            } else if !fillerWords.contains(word), !isYear(word) {
                result.insert(word)
            }
            index += 1
        }
        return result
    }

    private static func isYear(_ word: String) -> Bool {
        word.count == 4 && word.allSatisfy(\.isNumber) && (word.hasPrefix("19") || word.hasPrefix("20"))
    }

    /// "Stage 5" → "5"; nil for non-numbered parts like "Elite Women Road Race".
    private static func stageNumber(_ stage: String?) -> String? {
        let parts = words(stage ?? "")
        guard parts.count >= 2, parts[0] == "stage", HomeRaces.Stage.isStageNumber(parts[1]) else { return nil }
        return parts[1]
    }

    private static func facets(category: String) -> (Gender?, Age?) {
        let code = Array(category.uppercased())
        guard code.count == 2 else { return (nil, nil) }
        let gender: Gender? = code[0] == "M" ? .men : code[0] == "W" ? .women : nil
        let age: Age? = switch code[1] {
        case "E": .elite
        case "U": .u23
        case "J": .junior
        default: nil
        }
        return (gender, age)
    }

    // Women first: the schedule's category can read "(Men)" on a row whose name says women.
    private static func gender(in text: String) -> Gender? {
        let found = Set(words(text))
        if !found.isDisjoint(with: ["women", "woman", "femmes", "femenina", "donne", "dames", "ladies"]) {
            return .women
        }
        return found.contains("men") ? .men : nil
    }

    private static func age(in text: String) -> Age? {
        let found = words(text)
        if found.contains(where: { $0 == "junior" || $0 == "juniors" }) {
            return .junior
        }
        let isUnder23 = found.contains("u23")
            || zip(found, found.dropFirst()).contains { $0 == "under" && $1 == "23" }
        return isUnder23 ? .u23 : nil
    }
}

extension HomeRaces.WhereToWatch.RaceKey {
    init(
        race: HomeRaces.Representable.RaceNext,
        now: Date = Date()
    ) {
        let stage = HomeRaces.Stage.split(name: race.name)?.stage
            ?? HomeRaces.Stage.number(inURL: race.urlPath.flatMap { URL(string: $0) })
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = HomeRaces.WhereToWatch.scheduleTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.init(
            name: race.title,
            stage: stage,
            raceClass: race.raceType,
            category: race.category,
            date: formatter.string(from: race.finishDate ?? now)
        )
    }
}
