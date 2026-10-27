import SwiftUI

/// In-memory store for demo data. Tow requests live in `TowService` (Firestore).
@Observable
final class AppState {
    var role: UserRole?
    var userName = "Sasanka Pasenadhi"
    var email = "sasanka@example.com"
    var profileImageData: Data?

    var vehicles = MockData.vehicles
    var records = MockData.records
    var appointments = MockData.appointments
    var inventory = MockData.inventory
    var staff = MockData.staff
    var expenses = MockData.expenses
    var revenue = MockData.revenue
    var notifications = MockData.notifications
    var anomalies = MockData.anomalies

    /// Set by RootView so Settings can trigger a real sign-out.
    @ObservationIgnored var signOutHandler: (() -> Void)?

    init(role: UserRole? = nil) {
        self.role = role
        revenue = MLService.shared.extendRevenue(MockData.revenue)   // Core ML forecast
        refreshNoShowRisk()                                           // Core ML classifier
    }

    /// Runs the on-device no-show model for every appointment.
    func refreshNoShowRisk() {
        for i in appointments.indices {
            let a = appointments[i]
            let weekday = Calendar.current.component(.weekday, from: a.date)   // Sun = 1
            let mondayFirst = (weekday + 5) % 7 + 1                              // Mon = 1 … Sun = 7
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

    func setStatus(_ id: UUID, _ status: AppointmentStatus) {
        guard let i = appointments.firstIndex(where: { $0.id == id }) else { return }
        appointments[i].status = status
    }

    // MARK: Vehicles
    func updateVehicle(_ vehicle: Vehicle) {
        guard let i = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[i] = vehicle
        publishWidgetSnapshot()
    }

    func removeVehicle(_ id: UUID) {
        vehicles.removeAll { $0.id == id }
        records.removeAll { $0.vehicleID == id }
        publishWidgetSnapshot()
    }

    func signOut() {
        role = nil
        signOutHandler?()
    }
}
