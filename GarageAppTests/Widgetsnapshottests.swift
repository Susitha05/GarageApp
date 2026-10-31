import XCTest
@testable import GarageApp

/// Tests the data the widget and Siri read.
final class WidgetSnapshotTests: XCTestCase {

    private let key = "widget.snapshot"
    private var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.id) }
    private var backup: Data?

    override func setUp() {
        super.setUp()
        backup = defaults?.data(forKey: key)     // keep the real snapshot safe
    }

    override func tearDown() {
        if let backup { defaults?.set(backup, forKey: key) } else { defaults?.removeObject(forKey: key) }
        super.tearDown()
    }

    func testAppGroupIdMatchesTheCapability() {
        XCTAssertEqual(AppGroup.id, "group.susitha.GarageApp")
    }

    func testSampleSnapshotValues() {
        let s = WidgetSnapshot.sample
        XCTAssertEqual(s.risk, "High")
        XCTAssertLessThan(s.dueInKm, 0)
        XCTAssertFalse(s.vehicleName.isEmpty)
        XCTAssertNil(s.towStatus)
    }

    func testSnapshotSurvivesEncoding() throws {
        let original = WidgetSnapshot.sample
        let copy = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(copy, original)
    }

    func testSaveThenLoadReturnsTheSameSnapshot() {
        let snapshot = WidgetSnapshot(vehicleName: "2019 Toyota Aqua", topPart: "Engine Oil", dueInKm: 1_200, risk: "Medium",
                                      nextAppointmentTitle: "Oil Change • AutoCare Garage",
                                      nextAppointmentDate: Date(timeIntervalSince1970: 1_800_000_000),
                                      towStatus: "En Route", updated: Date(timeIntervalSince1970: 1_700_000_000))
        WidgetSnapshotStore.save(snapshot)
        XCTAssertEqual(WidgetSnapshotStore.load(), snapshot)
    }

    func testLoadReturnsNilWhenNothingIsSaved() {
        defaults?.removeObject(forKey: key)
        XCTAssertNil(WidgetSnapshotStore.load())
    }

    func testPublishingWritesTheTopPredictionForTheFirstVehicle() {
        let app = AppState(role: .customer)
        let v = Vehicle(registration: "CAB-1", make: "Toyota", model: "Aqua", year: 2019, mileage: 60_000)
        app.vehicles = [v]
        app.records = []

        app.publishWidgetSnapshot()

        let saved = WidgetSnapshotStore.load()
        XCTAssertEqual(saved?.vehicleName, "2019 Toyota Aqua")
        XCTAssertEqual(saved?.topPart, "Air Filter")      // the most overdue part with no history
        XCTAssertEqual(saved?.dueInKm, -45_000)
    }
}
