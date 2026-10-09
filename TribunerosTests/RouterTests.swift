import XCTest
@testable import Tribuneros

final class RouterTests: XCTestCase {

    func testSameDestinationPushedTwiceIsPushedOnce() {
        let router = Router()
        router.routeTo(.todayRaces)
        router.routeTo(.todayRaces)
        XCTAssertEqual(router.navPath.count, 1)
    }

    func testDifferentDestinationAfterItIsPushed() {
        let router = Router()
        router.routeTo(.todayRaces)
        router.routeTo(.yesterdayResults)
        XCTAssertEqual(router.navPath.count, 2)
    }

    func testSameDestinationCanBePushedAgainAfterPop() {
        let router = Router()
        router.routeTo(.todayRaces)
        router.popToPrevious()
        router.routeTo(.todayRaces)
        XCTAssertEqual(router.navPath.count, 1)
    }

    func testWebIsUnaffected() throws {
        let router = Router()
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        router.routeTo(.web(url))
        router.routeTo(.web(url))
        XCTAssertEqual(router.navPath.count, 0)
        XCTAssertEqual(router.webPage?.url, url)
    }
}
