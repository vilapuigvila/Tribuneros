import Foundation

final class RequestThrottleController {
    private let minimumInterval: TimeInterval
    private let extraRequestsLimit: Int

    private var lastRequestAt: Date?
    private var lastOutcomeWasFailure = false
    private var extraRequestsUsed = 0

    init(minimumInterval: TimeInterval, extraRequestsLimit: Int) {
        self.minimumInterval = minimumInterval
        self.extraRequestsLimit = extraRequestsLimit
    }

    func canStartRequest(at date: Date = Date()) -> Bool {
        guard let lastRequestAt else { return true }
        if date.timeIntervalSince(lastRequestAt) >= minimumInterval {
            return true
        }
        if lastOutcomeWasFailure, extraRequestsUsed < extraRequestsLimit {
            return true
        }
        return false
    }

    func startRequestIfAllowed(at date: Date = Date()) -> Bool {
        guard canStartRequest(at: date) else { return false }
        registerRequest(at: date)
        return true
    }

    func registerRequest(at date: Date = Date()) {
        if let lastRequestAt, date.timeIntervalSince(lastRequestAt) >= minimumInterval {
            extraRequestsUsed = 0
            lastOutcomeWasFailure = false
        } else if lastRequestAt != nil, lastOutcomeWasFailure {
            extraRequestsUsed += 1
        }
        lastRequestAt = date
    }

    func registerOutcome(isFailure: Bool) {
        if isFailure {
            lastOutcomeWasFailure = true
        } else {
            lastOutcomeWasFailure = false
            extraRequestsUsed = 0
        }
    }

    func registerRequestOutcome(hasEmptySection: Bool, isFailure: Bool) {
        registerOutcome(isFailure: isFailure || hasEmptySection)
    }
}

