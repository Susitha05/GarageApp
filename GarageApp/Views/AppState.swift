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

    init(role: UserRole? = nil) { self.role = role }

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
