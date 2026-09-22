import XCTest
import Alfy
@testable import Tribuneros

final class RequestThrottleControllerTests: XCTestCase {
    func testStartRequestIfAllowedAllowsFirstRequest() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(controller.startRequestIfAllowed(at: startDate))
    }

    func testStartRequestIfAllowedBlocksWithinIntervalWithoutExtraRequests() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(controller.startRequestIfAllowed(at: startDate))

        let secondDate = startDate.addingTimeInterval(30)
        XCTAssertFalse(controller.startRequestIfAllowed(at: secondDate))
    }

    func testStartRequestIfAllowedAllowsExtraRequestsAfterFailure() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(controller.startRequestIfAllowed(at: startDate))
        controller.registerOutcome(isFailure: true)

        let secondDate = startDate.addingTimeInterval(10)
        XCTAssertTrue(controller.startRequestIfAllowed(at: secondDate))

        let thirdDate = startDate.addingTimeInterval(20)
        XCTAssertTrue(controller.startRequestIfAllowed(at: thirdDate))

        let fourthDate = startDate.addingTimeInterval(30)
        XCTAssertFalse(controller.startRequestIfAllowed(at: fourthDate))
    }

    func testStartRequestIfAllowedGrantsExtraRequestsAgainAfterIntervalReset() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(controller.startRequestIfAllowed(at: startDate))
        controller.registerOutcome(isFailure: true)

        let firstExtraDate = startDate.addingTimeInterval(10)
        XCTAssertTrue(controller.startRequestIfAllowed(at: firstExtraDate))

        let secondExtraDate = startDate.addingTimeInterval(20)
        XCTAssertTrue(controller.startRequestIfAllowed(at: secondExtraDate))

        let resetDate = secondExtraDate.addingTimeInterval(61)
        XCTAssertTrue(controller.startRequestIfAllowed(at: resetDate))
        controller.registerOutcome(isFailure: true)

        let newExtraDate = resetDate.addingTimeInterval(10)
        XCTAssertTrue(controller.startRequestIfAllowed(at: newExtraDate))
    }

    private func makeSut() -> RequestThrottleController {
        RequestThrottleController(
            minimumInterval: 60,
            extraRequestsLimit: 2
        )
    }
}
