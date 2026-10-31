import XCTest
@testable import GarageApp

/// Tests AppState logic that does not touch the cloud: staff workload and turning completed bookings into history.
final class AppStateLogicTests: XCTestCase {

    // AppState writes garage-data.json, so back up and restore the real one.
    private var saveURL: URL { URL.documentsDirectory.appending(path: "garage-data.json") }
    private var backup: Data?

    override func setUp() {
        super.setUp()
        backup = try? Data(contentsOf: saveURL)
        try? FileManager.default.removeItem(at: saveURL)
    }

    override func tearDown() {
        if let backup { try? backup.write(to: saveURL) } else { try? FileManager.default.removeItem(at: saveURL) }
        super.tearDown()
    }

    private func vehicle() -> Vehicle {
        Vehicle(registration: "CAB-1234", make: "Toyota", model: "Aqua", year: 2019, mileage: 60_000)
    }

    private func booking(status: AppointmentStatus, staff: String? = nil, vehicleTitle: String = "",
                         service: ServiceKind = .oilChange, uid: String = "") -> Appointment {
        Appointment(customerName: "Sasanka", vehicleTitle: vehicleTitle, service: service,
                    date: .now, status: status, assignedStaff: staff, customerUid: uid)
    }

    // MARK: - Staff workload
    func testStaffLoadCountsOnlyOpenJobsOfThatMechanic() {
        let app = AppState(role: .garageOwner)
        app.staff = [StaffMember(name: "Nimal", role: "Mechanic", assignedJobs: 99, completedJobs: 0)]
        app.appointments = [
            booking(status: .pending, staff: "Nimal"),
            booking(status: .accepted, staff: "Nimal"),
            booking(status: .inProgress, staff: "Nimal"),
            booking(status: .completed, staff: "Nimal"),     // finished, not counted
            booking(status: .rejected, staff: "Nimal"),      // rejected, not counted
            booking(status: .pending, staff: "Kasun"),       // someone else
            booking(status: .pending, staff: nil)            // unassigned
        ]
        app.refreshStaffLoad()
        XCTAssertEqual(app.staff[0].assignedJobs, 3)
    }

    func testStaffLoadResetsToZeroWithNoAppointments() {
        let app = AppState(role: .garageOwner)
        app.staff = [StaffMember(name: "Nimal", role: "Mechanic", assignedJobs: 5, completedJobs: 0)]
        app.appointments = []
        app.refreshStaffLoad()
        XCTAssertEqual(app.staff[0].assignedJobs, 0)
    }

    // MARK: - Completed bookings become service history
    func testCompletedBookingCreatesOneServiceRecord() {
        let app = AppState(role: .customer)
        let v = vehicle()
        app.userUid = "u1"
        app.vehicles = [v]
        app.records = []
        let a = booking(status: .completed, vehicleTitle: v.title, service: .oilChange, uid: "u1")
        app.appointments = [a]

        app.recordCompletedServices()

        XCTAssertEqual(app.records.count, 1)
        XCTAssertEqual(app.records.first?.vehicleID, v.id)
        XCTAssertEqual(app.records.first?.parts, ["Engine Oil"])
        XCTAssertEqual(app.records.first?.cost, ServiceKind.oilChange.basePrice)
        XCTAssertEqual(app.records.first?.appointmentID, a.id)
    }

    func testRunningItTwiceDoesNotDuplicateTheRecord() {
        let app = AppState(role: .customer)
        let v = vehicle()
        app.userUid = "u1"
        app.vehicles = [v]
        app.records = []
        app.appointments = [booking(status: .completed, vehicleTitle: v.title, uid: "u1")]

        app.recordCompletedServices()
        app.recordCompletedServices()

        XCTAssertEqual(app.records.count, 1)
    }

    func testUnfinishedOrForeignBookingsAreIgnored() {
        let app = AppState(role: .customer)
        let v = vehicle()
        app.userUid = "u1"
        app.vehicles = [v]
        app.records = []
        app.appointments = [
            booking(status: .pending, vehicleTitle: v.title, uid: "u1"),                 // not finished
            booking(status: .completed, vehicleTitle: v.title, uid: "someone-else"),     // another customer
            booking(status: .completed, vehicleTitle: "2000 Honda Civic", uid: "u1")     // vehicle not on this phone
        ]

        app.recordCompletedServices()

        XCTAssertTrue(app.records.isEmpty)
    }

    func testGarageOwnersNeverGetCustomerHistory() {
        let app = AppState(role: .garageOwner)
        let v = vehicle()
        app.userUid = "u1"
        app.vehicles = [v]
        app.records = []
        app.appointments = [booking(status: .completed, vehicleTitle: v.title, uid: "u1")]

        app.recordCompletedServices()

        XCTAssertTrue(app.records.isEmpty)
    }

    func testHistoryFromABookingChangesThePrediction() {
        let app = AppState(role: .customer)
        let v = vehicle()
        app.userUid = "u1"
        app.vehicles = [v]
        app.records = []
        let before = MaintenancePredictor().predict(for: v, records: app.records).first { $0.part == "Engine Oil" }?.dueInKm
        XCTAssertEqual(before, -55_000)

        app.appointments = [booking(status: .completed, vehicleTitle: v.title, service: .oilChange, uid: "u1")]
        app.recordCompletedServices()

        let after = MaintenancePredictor().predict(for: v, records: app.records).first { $0.part == "Engine Oil" }?.dueInKm
        XCTAssertEqual(after, 5_000)      // record uses the current mileage, so a full interval remains
    }
}
