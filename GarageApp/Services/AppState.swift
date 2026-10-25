import SwiftUI

/// Central in-memory store. Replace the mock arrays with Firestore listeners later.
@Observable
final class AppState {
    var role: UserRole?
    var userName = "Sasanka Pasenadhi"
    var email = "sasanka@example.com"

    var vehicles = MockData.vehicles
    var records = MockData.records
    var appointments = MockData.appointments
    var inventory = MockData.inventory
    var staff = MockData.staff
    var towRequests = MockData.towRequests
    var expenses = MockData.expenses
    var revenue = MockData.revenue
    var notifications = MockData.notifications
    var anomalies = MockData.anomalies
    var activeJobID: UUID?

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
        WidgetSnapshotStore.save(WidgetSnapshot(
            vehicleName: v.title, topPart: top.part, dueInKm: top.dueInKm, risk: top.risk.rawValue,
            nextAppointmentTitle: next.map { "\($0.service.rawValue) • \($0.garage)" },
            nextAppointmentDate: next?.date,
            towStatus: towRequests.first { $0.id == activeJobID }?.status.rawValue,
            updated: .now))
    }

    func setStatus(_ id: UUID, _ status: AppointmentStatus) {
        guard let i = appointments.firstIndex(where: { $0.id == id }) else { return }
        appointments[i].status = status
    }

    func acceptJob(_ id: UUID) {
        guard let i = towRequests.firstIndex(where: { $0.id == id }) else { return }
        towRequests[i].status = .accepted
        activeJobID = id
    }

    func advanceActiveJob() {
        guard let id = activeJobID, let i = towRequests.firstIndex(where: { $0.id == id }),
              let next = towRequests[i].status.next else { return }
        towRequests[i].status = next
        if next == .completed { activeJobID = nil }
    }

    func signOut() { role = nil }
}
