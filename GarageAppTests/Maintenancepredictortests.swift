import XCTest
@testable import GarageApp

/// Tests for the km-until-due logic, the risk rule and the confidence rule in MaintenancePredictor.
final class MaintenancePredictorTests: XCTestCase {

    private let predictor = MaintenancePredictor()

    private func vehicle(mileage: Int) -> Vehicle {
        Vehicle(registration: "CAB-1234", make: "Toyota", model: "Aqua", year: 2019, mileage: mileage)
    }

    private func record(_ v: Vehicle, at mileage: Int, parts: [String]) -> ServiceRecord {
        ServiceRecord(vehicleID: v.id, title: "Service", date: .now, mileage: mileage,
                      cost: 1_000, garage: "AutoCare Garage", parts: parts)
    }

    private func due(_ part: String, _ v: Vehicle, _ records: [ServiceRecord]) -> Int? {
        predictor.predict(for: v, records: records).first { $0.part == part }?.dueInKm
    }

    // MARK: - km until due (never changed by the Core ML model)
    func testBrandNewCarIsNotDue() {
        let v = vehicle(mileage: 0)
        XCTAssertEqual(due("Engine Oil", v, []), 5_000)
        XCTAssertEqual(due("Battery", v, []), 50_000)
    }

    func testOnePartServiceDoesNotAffectOtherParts() {
        let v = vehicle(mileage: 60_000)
        let r = record(v, at: 59_000, parts: ["Engine Oil"])
        XCTAssertEqual(due("Engine Oil", v, [r]), 4_000)
        XCTAssertEqual(due("Brake Pads", v, [r]), -30_000)
    }

    func testFullServiceResetsOilAndAirFilterOnly() {
        let v = vehicle(mileage: 60_000)
        let r = record(v, at: 60_000, parts: ServiceKind.fullService.partsReplaced)
        XCTAssertEqual(due("Engine Oil", v, [r]), 5_000)
        XCTAssertEqual(due("Air Filter", v, [r]), 15_000)
        XCTAssertEqual(due("Tyres", v, [r]), -20_000)
    }

    func testMostUrgentPartIsFirstAndFreshestIsLast() {
        let v = vehicle(mileage: 60_000)
        let r = record(v, at: 59_000, parts: ["Engine Oil"])
        let result = predictor.predict(for: v, records: [r])
        XCTAssertEqual(result.first?.part, "Air Filter")     // -45,000, the most overdue
        XCTAssertEqual(result.last?.part, "Engine Oil")      // 4,000 left
    }

    // MARK: - Risk rule (only checked when no Core ML model is bundled)
    func testRiskIsHighWhenOverdue() throws {
        try XCTSkipIf(MLService.shared.maintenanceLoaded, "Core ML model replaces the rule-based risk")
        let v = vehicle(mileage: 60_000)
        let r = record(v, at: 50_000, parts: ["Engine Oil"])           // due = -5,000
        XCTAssertEqual(predictor.predict(for: v, records: [r]).first { $0.part == "Engine Oil" }?.risk, .high)
    }

    func testRiskIsMediumWhenUnderAFifthOfTheIntervalIsLeft() throws {
        try XCTSkipIf(MLService.shared.maintenanceLoaded, "Core ML model replaces the rule-based risk")
        let v = vehicle(mileage: 60_000)
        let r = record(v, at: 55_500, parts: ["Engine Oil"])           // due = 500 (< 1,000)
        XCTAssertEqual(predictor.predict(for: v, records: [r]).first { $0.part == "Engine Oil" }?.risk, .medium)
    }

    func testRiskIsLowWhenPlentyIsLeft() throws {
        try XCTSkipIf(MLService.shared.maintenanceLoaded, "Core ML model replaces the rule-based risk")
        let v = vehicle(mileage: 60_000)
        let r = record(v, at: 56_500, parts: ["Engine Oil"])           // due = 1,500
        XCTAssertEqual(predictor.predict(for: v, records: [r]).first { $0.part == "Engine Oil" }?.risk, .low)
    }

    
    func testConfidenceGrowsWithHistoryAndIsCapped() throws {
        try XCTSkipIf(MLService.shared.maintenanceLoaded, "Core ML model supplies the confidence")
        let v = vehicle(mileage: 60_000)

        XCTAssertEqual(predictor.predict(for: v, records: []).first?.confidence ?? 0, 0.60, accuracy: 0.001)

        let one = [record(v, at: 50_000, parts: [])]
        XCTAssertEqual(predictor.predict(for: v, records: one).first?.confidence ?? 0, 0.67, accuracy: 0.001)

        let many = (0..<10).map { record(v, at: 40_000 + $0 * 1_000, parts: []) }
        XCTAssertEqual(predictor.predict(for: v, records: many).first?.confidence ?? 0, 0.95, accuracy: 0.001)
    }
}
