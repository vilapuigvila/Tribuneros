//
//  Service+RemoteConfig.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import Foundation
import FirebaseRemoteConfig

extension Service {
    static let pressURLsKey = "press_urls"
    static let courseDuJourNativeKey = "ct_coursedujour_native"

    private static let defaultPressURLs = """
    [
        {"Ciclismo 2005": "https://ciclismo2005.com"},
        {"Escape Collective": "https://escapecollective.com"},
        {"Cycling News": "https://www.cyclingnews.com"},
        {"Cycling Update": "https://cyclinguptodate.com"},
        {"Ciclismo al dia": "https://ciclismoaldia.es"},
        {"Joan Seguidor": "https://joanseguidor.com"}
    ]
    """

    private static let remoteConfig: RemoteConfig = {
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #endif
        settings.minimumFetchInterval = 3600*12 // 12 hour
        config.configSettings = settings
        config.setDefaults([
            pressURLsKey: defaultPressURLs as NSString,
            courseDuJourNativeKey: false as NSNumber
        ])
        return config
    }()

    /// Warms the activated values at launch, so flags are current without opening Paddock first.
    static func refreshRemoteConfig() {
        Task {
            _ = try? await remoteConfig.fetchAndActivate()
        }
    }

    /// Native Course du Jour schedule behind "Where to watch" instead of the web page.
    static var isCourseDuJourNativeEnabled: Bool {
        #if DEBUG
        if let override = courseDuJourNativeOverride {
            return override
        }
        #endif
        return remoteConfig.configValue(forKey: courseDuJourNativeKey).boolValue
    }

    #if DEBUG
    /// `CT_COURSEDUJOUR_NATIVE` or the `ctCoursedujourNative` launch argument: on/off, bypasses Remote Config.
    static var courseDuJourNativeOverride: Bool? {
        courseDuJourNativeOverride(
            environment: ProcessInfo.processInfo.environment,
            launchValue: UserDefaults.standard.string(forKey: "ctCoursedujourNative")
        )
    }

    static func courseDuJourNativeOverride(
        environment: [String: String],
        launchValue: String?
    ) -> Bool? {
        (environment["CT_COURSEDUJOUR_NATIVE"] ?? launchValue)
            .map { ["1", "on", "true", "yes"].contains($0.lowercased()) }
    }
    #endif

    static func getPressLinks() async -> [DTO.PressLink] {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.pressLinks
        }
        #endif
        // A failed fetch keeps the last activated value, or the in-app default.
        _ = try? await remoteConfig.fetchAndActivate()
        return cachedPressLinks()
    }

    /// The press list available without a network round trip: the value activated on a previous
    /// launch (Remote Config persists it), or the in-app default on first launch.
    static func cachedPressLinks() -> [DTO.PressLink] {
        parsePressLinks(remoteConfig.configValue(forKey: pressURLsKey).dataValue)
    }

    static func parsePressLinks(_ data: Data) -> [DTO.PressLink] {
        guard let entries = try? JSONDecoder().decode([PressEntry].self, from: data) else {
            nonFatalCrashlytics(false, "Remote Config '\(pressURLsKey)' is not a JSON array")
            return []
        }
        return entries.flatMap { entry -> [DTO.PressLink] in
            switch entry {
            case .url(let value):
                return webURL(value).map { [DTO.PressLink(name: nil, url: $0)] } ?? []
            case .named(let values):
                return values
                    .sorted { $0.key < $1.key }
                    .compactMap { name, value in
                        webURL(value).map { DTO.PressLink(name: name, url: $0) }
                    }
            case .unsupported:
                return []
            }
        }
    }

    private static func webURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            return nil
        }
        return url
    }

    // Each entry is either a plain URL string or a {"Name": "url"} object.
    private enum PressEntry: Decodable {
        case url(String)
        case named([String: String])
        case unsupported

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .url(value)
            } else if let values = try? container.decode([String: String].self) {
                self = .named(values)
            } else {
                self = .unsupported
            }
        }
    }
}
