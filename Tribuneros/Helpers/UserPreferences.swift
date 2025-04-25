//
//  UserPreferences.swift
//  meteocat
//
//  Created by albert vila on 6/2/25.
//

import Foundation
import Combine

enum UserPreferencesKey: String {
    case lastListStationsRequest
    case spoilerModeResultsToday
    case spoilerModeResultsYesterday
    case spoilerModeResultsTomorrow
}

@propertyWrapper
struct UserDefault<T: Codable> {
    private let queue = DispatchQueue(label: "UserDefaultQueue_\(UUID().uuidString)")
    private let subject: CurrentValueSubject<T?, Never>
    
    let key: String
    let defaultValue: T?
    
    
    init(_ key: String, defaultValue: T?) {
        self.key = key
        self.defaultValue = defaultValue
        
        let initialValue: T? = queue.sync {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
            return defaultValue
        }
        self.subject = CurrentValueSubject<T?, Never>(initialValue)
    }

    var wrappedValue: T? {
        get {
            return queue.sync {
                if let data = UserDefaults.standard.data(forKey: key),
                   let decodedValue = try? JSONDecoder().decode(T.self, from: data) {
                    return decodedValue
                }
                return defaultValue
            }
        }
        set {
            queue.sync {
                if let encodedValue = try? JSONEncoder().encode(newValue) {
                    printInfo(true)
                    UserDefaults.standard.set(encodedValue, forKey: key)
                } else {
                    printInfo(false)
                    UserDefaults.standard.removeObject(forKey: key)
                }
                NotificationCenter.default.post(name: .userDefaultsChanged, object: key)
            }
        }
    }
    var projectedValue: AnyPublisher<T?, Never> {
        subject.eraseToAnyPublisher()
    }
    /*
    var projectedValue: AnyPublisher<T?, Never> {
        NotificationCenter.default.publisher(for: .userDefaultsChanged)
            .filter { notification in
                guard let changedKey = notification.object as? String else { return false }
                return changedKey == key
            }
            .map { [key, defaultValue] _ in
                // Return the new value from UserDefaults or the default.
                if let data = UserDefaults.standard.data(forKey: key),
                   let value = try? JSONDecoder().decode(T.self, from: data) {
                    return value
                }
                return defaultValue
            }
            .eraseToAnyPublisher()
    }*/
    
    private func printInfo(_ hasSet: Bool) {
#if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let source = hasSet ? "added" : "removed"
        print("[PREFERENCE] - \(source) for key: \(key) at: \(formatter.string(from: Date()))")
#endif
    }
}

enum PREF {
    
    /*
    struct HomeStation: Codable, Equatable {
        let name: String
        let code: String
    }
    
    struct LastRequests: Codable, Hashable {
        struct Request: Codable, Hashable {
            let timeInterval: TimeInterval
            let code: String
        }
        let requests: [LastRequests.Request]
        
        func append(_ request: Request) -> Self {
            let updated = Array(requests.drop(while: { $0.code == request.code }))
            return LastRequests(requests: updated + CollectionOfOne(request))
        }
    }*/
}

struct UserSettings {
    /*
    @UserDefault(UserPreferencesKey.homeStation.rawValue, defaultValue: nil)
    static var homeStation: PREF.HomeStation?
    static var homeStationPublisher: AnyPublisher<PREF.HomeStation?, Never> {
        _homeStation.projectedValue
    }
    
    @UserDefault(UserPreferencesKey.lastHomeStationRequest.rawValue, defaultValue: nil)
    static var lastHomeStationRequest: PREF.LastRequests?*/
    
//    @UserDefault(UserPreferencesKey.spoilerModeResultsToday.rawValue, defaultValue: nil)
//    static var lastListStationsRequest: TimeInterval?
    
    @UserDefault(UserPreferencesKey.spoilerModeResultsToday.rawValue, defaultValue: false)
    static var spoilerModeResultsToday: Bool?
    
    @UserDefault(UserPreferencesKey.spoilerModeResultsYesterday.rawValue, defaultValue: false)
    static var spoilerModeResultsYesterday: Bool?
    @UserDefault(UserPreferencesKey.spoilerModeResultsTomorrow.rawValue, defaultValue: false)
    static var spoilerModeResultsTomorrow: Bool?
}


extension Notification.Name {
    static let userDefaultsChanged = Notification.Name("userDefaultsChanged")
}

extension UserDefaults {
    func publisher<T: Codable>(for key: String, defaultValue: T) -> AnyPublisher<T, Never> {
        NotificationCenter.default.publisher(for: .userDefaultsChanged)
            .compactMap { notification -> T? in
                guard let changedKey = notification.object as? String, changedKey == key else { return nil }
                return UserDefaults.standard.decode(T.self, forKey: key) ?? defaultValue
            }
            .eraseToAnyPublisher()
    }
    
    func decode<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

extension Date {
    var differenceInHoursFromNow: Int {
        return Calendar.current.dateComponents([.hour], from: self, to: Date()).hour ?? 0
    }
    var differenceInSecondsFromNow: Int {
        return Calendar.current.dateComponents([.second], from: self, to: Date()).second ?? 0
    }
}
