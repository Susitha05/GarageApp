import XCTest
import CoreLocation
@testable import GarageApp

final class GarageAppTests: XCTestCase {

    // MARK: - Helpers
    private let partNames = ["Engine Oil", "Air Filter", "Brake Pads", "Tyres", "Battery"]

    private func makeVehicle(mileage: Int = 60_000) -> Vehicle {
        Vehicle(registration: "CAB-1234", make: "Toyota", model: "Aqua", year: 2019, mileage: mileage)
    }

    private func makeRecord(for vehicle: Vehicle, mileage: Int, parts: [String]) -> ServiceRecord {
        ServiceRecord(vehicleID: vehicle.id, title: "Service", date: .now, mileage: mileage,
                      cost: 3_500, garage: "AutoCare Garage", parts: parts)
    }

    // MARK: - Save file isolation (AppState writes garage-data.json)
    private var saveURL: URL { URL.documentsDirectory.appending(path: "garage-data.json") }
    private var savedBackup: Data?

    override func setUp() {
        super.setUp()
        savedBackup = try? Data(contentsOf: saveURL)   // keep the developer's real data safe
        try? FileManager.default.removeItem(at: saveURL)
    }

    override func tearDown() {
        if let savedBackup { try? savedBackup.write(to: saveURL) }
        else { try? FileManager.default.removeItem(at: saveURL) }
        super.tearDown()
    }

    // MARK: - 1. Status enums
    func testAppointmentStatusCodeRoundTrip() {
        for status in AppointmentStatus.allCases {
            XCTAssertEqual(AppointmentStatus(code: status.code), status)
        }
        XCTAssertNil(AppointmentStatus(code: "not-a-status"))
    }

    func testTowStatusCodeRoundTrip() {
        for status in TowStatus.allCases {
            XCTAssertEqual(TowStatus(code: status.code), status)
        }
        XCTAssertNil(TowStatus(code: "not-a-status"))
    }

    func testTowStatusProgression() {
        XCTAssertEqual(TowStatus.requested.next, .accepted)
        XCTAssertEqual(TowStatus.accepted.next, .enRoute)
        XCTAssertEqual(TowStatus.arrived.next, .towing)
        XCTAssertEqual(TowStatus.towing.next, .completed)
        XCTAssertNil(TowStatus.completed.next)
        XCTAssertNil(TowStatus.cancelled.next)
    }

    func testTowStatusIsActive() {
        XCTAssertTrue(TowStatus.requested.isActive)
        XCTAssertTrue(TowStatus.towing.isActive)
        XCTAssertFalse(TowStatus.completed.isActive)
        XCTAssertFalse(TowStatus.cancelled.isActive)
    }

    // MARK: - 2. Models
    func testVehicleTitle() {
        XCTAssertEqual(makeVehicle().title, "2019 Toyota Aqua")
    }

    func testTowRequestCoordinates() {
        var request = TowRequest(customerName: "Sasanka", vehicleTitle: "2019 Toyota Aqua", address: "Colombo",
                                 latitude: 6.9271, longitude: 79.8612, status: .requested)
        XCTAssertEqual(request.coordinate.latitude, 6.9271, accuracy: 0.0001)
        XCTAssertNil(request.driverCoordinate)

        request.driverLatitude = 6.93
        request.driverLongitude = 79.87
        XCTAssertEqual(request.driverCoordinate?.longitude ?? 0, 79.87, accuracy: 0.0001)
    }

    func testInventoryLowStockFlag() {
        let low = InventoryItem(name: "Oil Filter", sku: "OF-1", stock: 5, minThreshold: 5, usedThisMonth: 0, forecastNextMonth: 0)
        let ok = InventoryItem(name: "Oil Filter", sku: "OF-1", stock: 6, minThreshold: 5, usedThisMonth: 0, forecastNextMonth: 0)
        XCTAssertTrue(low.isLow)
        XCTAssertFalse(ok.isLow)
    }

    func testStaffLoadIsCappedAtOne() {
        XCTAssertEqual(StaffMember(name: "A", role: "Mechanic", assignedJobs: 4, completedJobs: 0).load, 0.5, accuracy: 0.001)
        XCTAssertEqual(StaffMember(name: "B", role: "Mechanic", assignedJobs: 20, completedJobs: 0).load, 1.0, accuracy: 0.001)
    }

    func testReceiptTotal() {
        let lines = [ReceiptLine(title: "Oil filter", quantity: 2, unitPrice: 1_500),
                     ReceiptLine(title: "Labour", quantity: 1, unitPrice: 3_500)]
        let receipt = Receipt(appointmentID: UUID(), number: "R-001", customerName: "Sasanka",
                              customerEmail: "s@example.com", vehicleTitle: "2019 Toyota Aqua",
                              garage: "AutoCare Garage", mechanic: "Nimal", lines: lines)
        XCTAssertEqual(lines[0].amount, 3_000)
        XCTAssertEqual(receipt.total, 6_500)
    }

    func testRupeeFormatter() {
        let text = rs(1_500)
        XCTAssertTrue(text.hasPrefix("Rs. "))
        XCTAssertEqual(text.filter(\.isNumber), "1500")
    }

    // MARK: - 3. Service catalogue
    func testServicePartsMatchPredictorNames() {
        for kind in ServiceKind.allCases {
            for part in kind.partsReplaced {
                XCTAssertTrue(partNames.contains(part), "\(kind.rawValue) lists unknown part \(part)")
            }
        }
        XCTAssertEqual(ServiceKind.fullService.partsReplaced, ["Engine Oil", "Air Filter"])
        XCTAssertTrue(ServiceKind.acService.partsReplaced.isEmpty)
    }

    func testServiceBasePricesArePositive() {
        for kind in ServiceKind.allCases { XCTAssertGreaterThan(kind.basePrice, 0) }
        XCTAssertEqual(ServiceKind.oilChange.basePrice, 3_500)
    }

    // MARK: - 4. Saving (Codable)
    func testVehicleAndRecordSurviveEncoding() throws {
        let vehicle = makeVehicle()
        let record = makeRecord(for: vehicle, mileage: 58_000, parts: ["Engine Oil"])

        let v = try JSONDecoder().decode(Vehicle.self, from: JSONEncoder().encode(vehicle))
        let r = try JSONDecoder().decode(ServiceRecord.self, from: JSONEncoder().encode(record))

        XCTAssertEqual(v.id, vehicle.id)
        XCTAssertEqual(v.mileage, 60_000)
        XCTAssertEqual(r.vehicleID, vehicle.id)
        XCTAssertEqual(r.parts, ["Engine Oil"])
        XCTAssertNil(r.appointmentID)
    }

    // MARK: - 5. Maintenance predictions
    func testPredictorReturnsFiveSortedParts() {
        let predictions = MaintenancePredictor().predict(for: makeVehicle(), records: [])
        XCTAssertEqual(predictions.count, 5)
        XCTAssertEqual(predictions.map(\.dueInKm), predictions.map(\.dueInKm).sorted())
        XCTAssertEqual(Set(predictions.map(\.part)), Set(partNames))
        for p in predictions { XCTAssertTrue((0...1).contains(p.confidence)) }
    }

    func testPredictorWithNoHistoryIsOverdue() {
        let predictions = MaintenancePredictor().predict(for: makeVehicle(mileage: 60_000), records: [])
        let oil = predictions.first { $0.part == "Engine Oil" }
        XCTAssertEqual(oil?.dueInKm, -55_000)          // 0 + 5,000 - 60,000
        XCTAssertEqual(predictions.first?.part, "Engine Oil")
    }

    func testServiceRecordResetsThePart() {
        let vehicle = makeVehicle(mileage: 60_000)
        let record = makeRecord(for: vehicle, mileage: 59_000, parts: ["Engine Oil"])
        let oil = MaintenancePredictor().predict(for: vehicle, records: [record]).first { $0.part == "Engine Oil" }
        XCTAssertEqual(oil?.dueInKm, 4_000)             // 59,000 + 5,000 - 60,000
    }

    func testPredictorUsesTheLatestServiceMileage() {
        let vehicle = makeVehicle(mileage: 60_000)
        let records = [makeRecord(for: vehicle, mileage: 50_000, parts: ["Engine Oil"]),
                       makeRecord(for: vehicle, mileage: 58_000, parts: ["Engine Oil"])]
        let oil = MaintenancePredictor().predict(for: vehicle, records: records).first { $0.part == "Engine Oil" }
        XCTAssertEqual(oil?.dueInKm, 3_000)
    }

    func testPredictorIgnoresOtherVehiclesRecords() {
        let vehicle = makeVehicle(mileage: 60_000)
        let other = makeVehicle(mileage: 60_000)
        let record = makeRecord(for: other, mileage: 59_000, parts: ["Engine Oil"])
        let oil = MaintenancePredictor().predict(for: vehicle, records: [record]).first { $0.part == "Engine Oil" }
        XCTAssertEqual(oil?.dueInKm, -55_000)
    }

    // MARK: - 6. Core ML service (works with or without the .mlmodel files)
    func testNoShowProbabilityIsNilOrAProbability() {
        let p = MLService.shared.noShowProbability(leadTimeDays: 3, dayOfWeek: 2, pastNoShows: 1, firstVisit: false)
        if let p { XCTAssertTrue((0...1).contains(p)) }
    }

    func testRevenueForecastExtendsTheSeries() {
        let month = Calendar.current.shortMonthSymbols[0]
        let actual = [RevenuePoint(month: month, amount: 100)]
        let result = MLService.shared.extendRevenue(actual, months: 2)
        XCTAssertEqual(result.count, 3)
        XCTAssertFalse(result[0].isForecast)
        XCTAssertTrue(result[1].isForecast)
        XCTAssertTrue(result[2].isForecast)
        XCTAssertEqual(result[1].month, Calendar.current.shortMonthSymbols[1])
    }

    // MARK: - 7. AppState (the bug we fixed: saving vehicles and history)
    func testAddedVehicleIsStillThereAfterRestart() {
        let vehicle = makeVehicle()
        let app = AppState(role: .customer)
        let before = app.vehicles.count
        app.addVehicle(vehicle)
        XCTAssertEqual(app.vehicles.count, before + 1)

        let restarted = AppState(role: .customer)       // simulates closing and reopening the app
        XCTAssertTrue(restarted.vehicles.contains { $0.id == vehicle.id })
    }

    func testLoggingAServiceUpdatesHistoryAndPrediction() {
        let app = AppState(role: .customer)
        let vehicle = makeVehicle(mileage: 60_000)
        app.addVehicle(vehicle)

        let before = MaintenancePredictor().predict(for: vehicle, records: app.records).first { $0.part == "Engine Oil" }
        XCTAssertEqual(before?.dueInKm, -55_000)

        app.addRecord(makeRecord(for: vehicle, mileage: 59_500, parts: ["Engine Oil"]))

        XCTAssertEqual(app.records.filter { $0.vehicleID == vehicle.id }.count, 1)
        let stored = app.vehicles.first { $0.id == vehicle.id }!
        let after = MaintenancePredictor().predict(for: stored, records: app.records).first { $0.part == "Engine Oil" }
        XCTAssertEqual(after?.dueInKm, 4_500)           // 59,500 + 5,000 - 60,000
    }

    func testServiceMileageOnlyEverGoesUp() {
        let app = AppState(role: .customer)
        let vehicle = makeVehicle(mileage: 50_000)
        app.addVehicle(vehicle)

        app.addRecord(makeRecord(for: vehicle, mileage: 52_000, parts: ["Engine Oil"]))
        XCTAssertEqual(app.vehicles.first { $0.id == vehicle.id }?.mileage, 52_000)

        app.addRecord(makeRecord(for: vehicle, mileage: 40_000, parts: ["Tyres"]))
        XCTAssertEqual(app.vehicles.first { $0.id == vehicle.id }?.mileage, 52_000)
    }

    func testRemovingAVehicleRemovesItsHistory() {
        let app = AppState(role: .customer)
        let vehicle = makeVehicle()
        app.addVehicle(vehicle)
        app.addRecord(makeRecord(for: vehicle, mileage: 60_000, parts: ["Engine Oil"]))

        app.removeVehicle(vehicle.id)

        XCTAssertFalse(app.vehicles.contains { $0.id == vehicle.id })
        XCTAssertFalse(app.records.contains { $0.vehicleID == vehicle.id })
    }
}
