import SwiftUI
import FirebaseCore

/// App-wide state. Appointments, inventory and receipts are synced with Firestore by `CloudStore`
/// (demo data is used in previews and in skip-login mode). Tow requests live in `TowService`.
@Observable
final class AppState {
    var role: UserRole?
    var userName = "Sasanka Pasenadhi"
    var email = "sasanka@example.com"
    var userUid = ""
    var profileImageData: Data?
    /// True while appointments / inventory / receipts are being synced from Firestore.
    var isCloud = false

    var vehicles = MockData.vehicles
    var records = MockData.records
    var appointments = MockData.appointments
    var inventory = MockData.inventory
    var staff = MockData.staff
    var receipts: [Receipt] = []
    var expenses = MockData.expenses
    var revenue = MockData.revenue
    var notifications = MockData.notifications
    var anomalies = MockData.anomalies

    /// Set by RootView so Settings can trigger a real sign-out.
    @ObservationIgnored var signOutHandler: (() -> Void)?

    init(role: UserRole? = nil) {
        self.role = role
        loadSaved()                            // restore saved vehicles + service history
        if FirebaseApp.app() != nil {          // real app: data arrives from Firestore
            appointments = []
            inventory = []
        }
        revenue = MLService.shared.extendRevenue(MockData.revenue)   // Core ML forecast
        refreshNoShowRisk()                                           // Core ML classifier
        refreshStaffLoad()
    }

    // MARK: Cloud / demo data
    func loadDemoData() {
        isCloud = false
        appointments = MockData.appointments
        inventory = MockData.inventory
        receipts = []
        appointmentsDidSync()
    }

    func clearCloudData() {
        guard FirebaseApp.app() != nil else { return }
        isCloud = false
        appointments = []
        inventory = []
        receipts = []
        refreshStaffLoad()
    }

    /// Called after appointments arrive from Firestore.
    func appointmentsDidSync() {
        refreshNoShowRisk()
        refreshStaffLoad()
        recordCompletedServices()              // completed bookings become service history
        publishWidgetSnapshot()
    }

    // MARK: Predictions & widget
    /// Runs the on-device no-show model for every appointment.
    func refreshNoShowRisk() {
        for i in appointments.indices {
            let a = appointments[i]
            let weekday = Calendar.current.component(.weekday, from: a.date)   // Sun = 1
            let mondayFirst = (weekday + 5) % 7 + 1                              // Mon = 1 ... Sun = 7
            if let p = MLService.shared.noShowProbability(leadTimeDays: a.bookedDaysAhead,
                                                          dayOfWeek: mondayFirst,
                                                          pastNoShows: a.pastNoShows,
                                                          firstVisit: a.isFirstVisit) {
                appointments[i].noShowRisk = p
            }
        }
    }

    /// Pushes the latest status to the home-screen / lock-screen widget.
    func publishWidgetSnapshot() {
        guard let v = vehicles.first,
              let top = MaintenancePredictor().predict(for: v, records: records).first else { return }
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let next = appointments
            .filter { $0.date >= startOfToday && ($0.status == .accepted || $0.status == .pending) }
            .min { $0.date < $1.date }
        let tow = TowService.shared.customerRequest.flatMap { $0.status.isActive ? $0.status.rawValue : nil }
        WidgetSnapshotStore.save(WidgetSnapshot(
            vehicleName: v.title, topPart: top.part, dueInKm: top.dueInKm, risk: top.risk.rawValue,
            nextAppointmentTitle: next.map { "\($0.service.rawValue) • \($0.garage)" },
            nextAppointmentDate: next?.date,
            towStatus: tow,
            updated: .now))
    }

    // MARK: Appointments & mechanics
    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        refreshNoShowRisk()
        CloudStore.shared.create(appointment)
    }

    func setStatus(_ id: UUID, _ status: AppointmentStatus) {
        guard var a = appointments.first(where: { $0.id == id }) else { return }
        a.status = status
        updateAppointment(a)
    }

    func updateAppointment(_ updated: Appointment) {
        guard let i = appointments.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = appointments[i]
        appointments[i] = updated
        if old.status != .completed, updated.status == .completed { creditCompletion(updated.assignedStaff) }
        refreshStaffLoad()
        refreshNoShowRisk()
        CloudStore.shared.save(updated)
    }

    func assign(_ id: UUID, to mechanic: String?) {
        guard let i = appointments.firstIndex(where: { $0.id == id }) else { return }
        appointments[i].assignedStaff = mechanic
        refreshStaffLoad()
        CloudStore.shared.save(appointments[i])
    }

    /// Open jobs per mechanic, calculated from the appointments assigned to them.
    func refreshStaffLoad() {
        for i in staff.indices {
            let name = staff[i].name
            staff[i].assignedJobs = appointments.filter {
                $0.assignedStaff == name &&
                ($0.status == .pending || $0.status == .accepted || $0.status == .inProgress)
            }.count
        }
    }

    private func creditCompletion(_ name: String?) {
        guard let name, let i = staff.firstIndex(where: { $0.name == name }) else { return }
        staff[i].completedJobs += 1
    }

    // MARK: Inventory
    func addInventoryItem(_ item: InventoryItem) {
        inventory.append(item)
        CloudStore.shared.save(item)
    }

    func updateInventoryItem(_ item: InventoryItem) {
        guard let i = inventory.firstIndex(where: { $0.id == item.id }) else { return }
        inventory[i] = item
        CloudStore.shared.save(item)
    }

    func removeInventoryItem(_ id: UUID) {
        inventory.removeAll { $0.id == id }
        CloudStore.shared.deleteInventory(id)
    }

    func adjustStock(_ id: UUID, by delta: Int, countAsUsed: Bool = false) {
        if let item = applyStock(id, by: delta, countAsUsed: countAsUsed) { CloudStore.shared.save(item) }
    }

    /// Changes the stock locally and returns the updated item (no network).
    @discardableResult
    private func applyStock(_ id: UUID, by delta: Int, countAsUsed: Bool) -> InventoryItem? {
        guard let i = inventory.firstIndex(where: { $0.id == id }) else { return nil }
        inventory[i].stock = max(0, inventory[i].stock + delta)
        if countAsUsed, delta < 0 { inventory[i].usedThisMonth += -delta }
        return inventory[i]
    }

    /// Adds a few example parts so a new (empty) inventory isn't blank.
    func seedSampleInventory() {
        for item in MockData.inventory {
            addInventoryItem(InventoryItem(name: item.name, sku: item.sku, stock: item.stock,
                                           minThreshold: item.minThreshold, usedThisMonth: item.usedThisMonth,
                                           forecastNextMonth: item.forecastNextMonth, unitPrice: item.unitPrice))
        }
    }

    // MARK: Receipts
    func receipt(for appointmentID: UUID) -> Receipt? {
        receipts.first { $0.appointmentID == appointmentID }
    }

    /// Stores the receipt and deducts the parts used from stock (saved together in Firestore).
    func issueReceipt(_ receipt: Receipt, parts: [(id: UUID, quantity: Int)]) {
        receipts.append(receipt)
        var changed: [InventoryItem] = []
        for part in parts {
            if let item = applyStock(part.id, by: -part.quantity, countAsUsed: true) { changed.append(item) }
        }
        CloudStore.shared.commitReceipt(receipt, items: changed)
    }

    func markReceiptSent(_ id: UUID) {
        guard let i = receipts.firstIndex(where: { $0.id == id }) else { return }
        receipts[i].sentAt = .now
        CloudStore.shared.save(receipts[i])
    }

    // MARK: Vehicles + service history (saved on the phone)
    func addVehicle(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
        persist()
        publishWidgetSnapshot()
    }

    func updateVehicle(_ vehicle: Vehicle) {
        guard let i = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[i] = vehicle
        persist()
        publishWidgetSnapshot()
    }

    func removeVehicle(_ id: UUID) {
        vehicles.removeAll { $0.id == id }
        records.removeAll { $0.vehicleID == id }
        persist()
        publishWidgetSnapshot()
    }

    /// Logs a service: updates history, mileage, predictions and the widget.
    func addRecord(_ record: ServiceRecord) {
        records.append(record)
        if let i = vehicles.firstIndex(where: { $0.id == record.vehicleID }) {
            vehicles[i].mileage = max(vehicles[i].mileage, record.mileage)
        }
        persist()
        publishWidgetSnapshot()
    }

    /// Turns the customer's completed bookings into service history (once per booking).
    func recordCompletedServices() {
        guard role == .customer, !userUid.isEmpty else { return }
        var added = false
        for a in appointments where a.status == .completed && a.customerUid == userUid {
            guard !records.contains(where: { $0.appointmentID == a.id }),
                  let v = vehicles.first(where: { $0.title == a.vehicleTitle }) else { continue }
            records.append(ServiceRecord(vehicleID: v.id, title: a.service.rawValue, date: a.date,
                                         mileage: v.mileage,
                                         cost: receipt(for: a.id)?.total ?? a.service.basePrice,
                                         garage: a.garage, parts: a.service.partsReplaced,
                                         appointmentID: a.id))
            added = true
        }
        if added { persist() }
    }

    // MARK: Persistence
    private static var saveURL: URL { URL.documentsDirectory.appending(path: "garage-data.json") }
    private struct Saved: Codable { var vehicles: [Vehicle]; var records: [ServiceRecord] }

    /// Replaces the mock data with whatever was saved last time (if a save file exists).
    private func loadSaved() {
        guard let data = try? Data(contentsOf: Self.saveURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        vehicles = saved.vehicles
        records = saved.records
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(Saved(vehicles: vehicles, records: records)) else { return }
        try? data.write(to: Self.saveURL, options: .atomic)
    }

    func signOut() {
        role = nil
        signOutHandler?()
    }
}
