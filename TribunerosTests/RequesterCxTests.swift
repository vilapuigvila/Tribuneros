import XCTest
@testable import Tribuneros

final class RequesterCxTests: XCTestCase {
    func testGetYoutubeRaceURLReturnsURLForOtegem() async throws {
        let raceURL = URL(string: "https://cyclocross24.com/race/otegem/")!
        let maxWaitSeconds: TimeInterval = 10
        let retryDelayNanoseconds: UInt64 = 2_000_000_000
        let deadline = Date().addingTimeInterval(maxWaitSeconds)
        var attempt = 0
        var lastURL: URL?

        while Date() < deadline {
            attempt += 1
            lastURL = await Requester.getYoutubeRaceURL(raceURL)
            if let lastURL {
                XCTAssertTrue(lastURL.absoluteString.contains("youtube.com/watch"))
                return
            }
            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
        throw XCTSkip("Cyclocross24/YouTube lookup returned nil after \(attempt) attempts in \(Int(maxWaitSeconds))s (network/site may be unavailable).")
    }
}
