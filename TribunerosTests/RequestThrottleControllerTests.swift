import XCTest
@testable import Tribuneros

final class RequestThrottleControllerTests: XCTestCase {
    func testCanStartRequestAllowsFirstRequest() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)
        
        let canStart = controller.canStartRequest(at: startDate)
        
        XCTAssertTrue(canStart)
    }
    
    func testCanStartRequestBlocksWithinIntervalWithoutExtraRequests() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)
        
        XCTAssertTrue(controller.canStartRequest(at: startDate))
        controller.registerRequest(at: startDate)
        
        let secondDate = startDate.addingTimeInterval(30)
        
        XCTAssertFalse(controller.canStartRequest(at: secondDate))
    }
    
    func testCanStartRequestAllowsExtraRequestsAfterFailure() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)
        
        XCTAssertTrue(controller.canStartRequest(at: startDate))
        controller.registerRequest(at: startDate)
        controller.registerRequestOutcome(
            hasEmptySection: false,
            isFailure: true
        )
        
        let secondDate = startDate.addingTimeInterval(10)
        XCTAssertTrue(controller.canStartRequest(at: secondDate))
        controller.registerRequest(at: secondDate)
        
        let thirdDate = startDate.addingTimeInterval(20)
        XCTAssertTrue(controller.canStartRequest(at: thirdDate))
        controller.registerRequest(at: thirdDate)
        
        let fourthDate = startDate.addingTimeInterval(30)
        XCTAssertFalse(controller.canStartRequest(at: fourthDate))
    }
    
    func testCanStartRequestGrantsExtraRequestsAgainAfterIntervalReset() {
        let controller = makeSut()
        let startDate = Date(timeIntervalSince1970: 1_000)
        
        XCTAssertTrue(controller.canStartRequest(at: startDate))
        controller.registerRequest(at: startDate)
        controller.registerRequestOutcome(
            hasEmptySection: false,
            isFailure: true
        )
        
        let firstExtraDate = startDate.addingTimeInterval(10)
        XCTAssertTrue(controller.canStartRequest(at: firstExtraDate))
        controller.registerRequest(at: firstExtraDate)
        
        let secondExtraDate = startDate.addingTimeInterval(20)
        XCTAssertTrue(controller.canStartRequest(at: secondExtraDate))
        controller.registerRequest(at: secondExtraDate)
        
        let resetDate = secondExtraDate.addingTimeInterval(61)
        XCTAssertTrue(controller.canStartRequest(at: resetDate))
        controller.registerRequest(at: resetDate)
        controller.registerRequestOutcome(
            hasEmptySection: false,
            isFailure: true
        )
        
        let newExtraDate = resetDate.addingTimeInterval(10)
        XCTAssertTrue(controller.canStartRequest(at: newExtraDate))
    }
    
    private func makeSut() -> RequestThrottleController {
        RequestThrottleController(
            minimumInterval: 60,
            extraRequestsLimit: 2
        )
    }
}
