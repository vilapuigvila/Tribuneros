import XCTest
@testable import Tribuneros

final class CachedURLSessionTests: XCTestCase {
    func testCachesCyclocross24WithinTTLWhenIgnoringServerCacheControl() async throws {
        let url = URL(string: "https://cyclocross24.com")!
        let namespace = "CachedURLSessionTests-\(UUID().uuidString)"
        let sut = CachedURLSession(
            ttl: 120,
            allowStaleOnError: false,
            cacheNamespace: namespace,
            cacheControlBehavior: .ignoreServer
        )

        let request = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 15
        )

        let first: (Data, URLResponse)
        do {
            first = try await sut.data(for: request)
        } catch {
            throw XCTSkip("Network unavailable or cyclocross24 unreachable: \(error)")
        }

        XCTAssertFalse(first.0.isEmpty)
        XCTAssertEqual(xCacheValue(from: first.1), "MISS")

        let second = try await sut.data(for: request)
        XCTAssertEqual(xCacheValue(from: second.1), "HIT")
        XCTAssertEqual(second.0, first.0)
    }

    func testDoesNotCacheCyclocross24WhenRespectingServerCacheControl() async throws {
        let url = URL(string: "https://cyclocross24.com")!
        let namespace = "CachedURLSessionTests-\(UUID().uuidString)"
        let sut = CachedURLSession(
            ttl: 120,
            allowStaleOnError: false,
            cacheNamespace: namespace,
            cacheControlBehavior: .respectServer
        )

        let request = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 15
        )

        let first: (Data, URLResponse)
        do {
            first = try await sut.data(for: request)
        } catch {
            throw XCTSkip("Network unavailable or cyclocross24 unreachable: \(error)")
        }

        XCTAssertFalse(first.0.isEmpty)
        XCTAssertEqual(xCacheValue(from: first.1), "MISS")

        let second = try await sut.data(for: request)
        XCTAssertEqual(xCacheValue(from: second.1), "MISS")
    }

    private func xCacheValue(from response: URLResponse) -> String? {
        (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "X-Cache")
    }
}

