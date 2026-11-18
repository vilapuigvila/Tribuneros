//
//  Service+AppStore.swift
//  Tribuneros
//

import Foundation
import Alfy

extension DTO {
    /// The version the App Store lists for this app and where to open it.
    struct AppStoreRelease: Equatable {
        let version: String
        let url: URL
    }
}

extension Service {

    private static let appStoreLookupTTL: CachedURLSession.TTL = .hours(1)

    /// The App Store's current version of this app; `nil` when the lookup fails or the app isn't listed in the device's storefront.
    static func getAppStoreRelease() async -> DTO.AppStoreRelease? {
        #if DEBUG
        if let version = UpdateAlert.debugVersion {
            return DTO.AppStoreRelease(
                version: version,
                url: UpdateAlert.debugURL
            )
        }
        #endif
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        // The lookup answers for one storefront: the device's first, then the default.
        var countries: [String?] = []
        if let region = Locale.current.region?.identifier.lowercased() {
            countries.append(region)
        }
        countries.append(nil)
        for country in countries {
            guard let url = appStoreLookupURL(
                bundleID: bundleID,
                country: country
            ) else {
                continue
            }
            do {
                let (data, _) = try await Requester
                    .makeRequest(url.absoluteString)
                    .ttl(appStoreLookupTTL)
                    .cacheControlBehavior(.ignoreServer)
                    .send()
                if let release = parseAppStoreLookup(data) {
                    return release
                }
            } catch {
                if !isOffline(error) {
                    nonFatalCrashlytics(false, "App Store lookup: \(error.localizedDescription)")
                }
                return nil
            }
        }
        return nil
    }

    static func appStoreLookupURL(
        bundleID: String,
        country: String?
    ) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        var items = [URLQueryItem(name: "bundleId", value: bundleID)]
        if let country {
            items.append(URLQueryItem(name: "country", value: country))
        }
        components?.queryItems = items
        return components?.url
    }

    /// The first result of an iTunes lookup. Its link must be https on an apple.com host; without one, the app's store page by `trackId`.
    static func parseAppStoreLookup(_ data: Data) -> DTO.AppStoreRelease? {
        struct Response: Decodable {
            struct Result: Decodable {
                let version: String?
                let trackViewUrl: String?
                let trackId: Int?
            }
            let results: [Result]
        }
        guard let result = (try? JSONDecoder().decode(Response.self, from: data))?.results.first,
              let version = result.version?.trimmingCharacters(in: .whitespaces),
              !version.isEmpty
        else {
            return nil
        }
        let listed = result.trackViewUrl.flatMap { URL(string: $0) }
        let url: URL
        if let listed, listed.scheme == "https", listed.host?.hasSuffix("apple.com") == true {
            url = listed
        } else if let trackId = result.trackId, let byID = URL(string: "https://apps.apple.com/app/id\(trackId)") {
            url = byID
        } else {
            return nil
        }
        return DTO.AppStoreRelease(
            version: version,
            url: url
        )
    }
}
