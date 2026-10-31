import XCTest
@testable import GarageApp

final class GarageAppTests: XCTestCase {

    // 1. Appointment status rules
    func testAppointmentStatusTransitions() {
        XCTAssertTrue(AppointmentStatus.pending.canTransition(to: .confirmed))
        XCTAssertTrue(AppointmentStatus.confirmed.canTransition(to: .inProgress))
        XCTAssertFalse(AppointmentStatus.pending.canTransition(to: .completed))
        XCTAssertFalse(AppointmentStatus.completed.canTransition(to: .pending))
    }

    // 2. Tow status steps
    func testTowStatusProgression() {
        XCTAssertEqual(TowStatus.accepted.next, .enRoute)
        XCTAssertEqual(TowStatus.towing.next, .completed)
        XCTAssertNil(TowStatus.completed.next)
        XCTAssertFalse(TowStatus.cancelled.isActive)
    }

    // 3. Maintenance prediction (rule-based)
    func testMaintenanceRemaining() {
        let overdue = MLService.ruleRemaining(.oilChange, kmSince: 12_000, daysSince: 100, avgKmPerMonth: 1000)
        let fresh = MLService.ruleRemaining(.oilChange, kmSince: 0, daysSince: 0, avgKmPerMonth: 1000)
        XCTAssertLessThan(overdue, 0)
        XCTAssertGreaterThan(fresh, 5_000)
    }

    // 4. Forecast follows a linear trend
    func testForecastFollowsTrend() {
        let history = (0..<12).map { Double($0) * 10 }
        let forecast = Analytics.forecast(history, season: 12, horizon: 2)
        XCTAssertEqual(forecast.count, 2)
        XCTAssertEqual(forecast[0], 120, accuracy: 0.5)
    }
}
