import Foundation
import FirebaseCore
import FirebaseFirestore

/// Syncs appointments, inventory and receipts with Firestore.
/// Document IDs are the models' UUID strings, so the rest of the app keeps using `UUID` ids.
///
///  • Customer: reads their own appointments and receipts, creates appointments.
///  • Garage owner: reads/writes all appointments and receipts for the garage, and the inventory.
///
/// Without Firebase (SwiftUI previews) or in skip-login mode nothing is synced and the demo data is used.
@Observable
final class CloudStore {
    static let shared = CloudStore()
    /// The garage managed by the owner account in this prototype.
    static let ownerGarage = "AutoCare Garage"

    var errorMessage: String?

    @ObservationIgnored private var listeners: [ListenerRegistration] = []
    @ObservationIgnored private weak var app: AppState?
    @ObservationIgnored private var user: AppUser?
    @ObservationIgnored private var attempts = 0
    @ObservationIgnored private var retryTask: Task<Void, Never>?

    var isConfigured: Bool { FirebaseApp.app() != nil }
    var isActive: Bool { isConfigured && user != nil }
    private var db: Firestore { Firestore.firestore() }

    // MARK: Listeners
    func start(user: AppUser, app: AppState) {
        removeListeners()
        guard isConfigured, user.uid != "dev" else { return }
        self.user = user
        self.app = app
        app.isCloud = true

        switch user.role {
        case .customer:
            listen(db.collection("appointments").whereField("customerUid", isEqualTo: user.uid)) { app, docs in
                app.appointments = docs.compactMap(Self.parseAppointment)
                app.appointmentsDidSync()
            }
            listen(db.collection("receipts").whereField("customerUid", isEqualTo: user.uid)) { app, docs in
                app.receipts = docs.compactMap(Self.parseReceipt).sorted { $0.date > $1.date }
            }
        case .garageOwner:
            listen(db.collection("appointments").whereField("garage", isEqualTo: Self.ownerGarage)) { app, docs in
                app.appointments = docs.compactMap(Self.parseAppointment)
                app.appointmentsDidSync()
            }
            listen(db.collection("inventory")) { app, docs in
                app.inventory = docs.compactMap(Self.parseItem).sorted { $0.name < $1.name }
            }
            listen(db.collection("receipts").whereField("garage", isEqualTo: Self.ownerGarage)) { app, docs in
                app.receipts = docs.compactMap(Self.parseReceipt).sorted { $0.date > $1.date }
            }
        case .towDriver:
            break
        }
    }

    func stop() {
        retryTask?.cancel()
        retryTask = nil
        removeListeners()
        user = nil
        attempts = 0
        errorMessage = nil
        app?.isCloud = false
        app = nil
    }

    private func removeListeners() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    private func listen(_ query: Query, apply: @escaping (AppState, [QueryDocumentSnapshot]) -> Void) {
        listeners.append(query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error { self.failed(error); return }
            guard let app = self.app, let snapshot else { return }
            self.attempts = 0
            self.errorMessage = nil
            apply(app, snapshot.documents)
        })
    }

    /// Firestore ends a listener after an error, so retry a few times automatically.
    private func failed(_ error: Error) {
        errorMessage = Self.readable(error)
        guard attempts < 3, user != nil, app != nil else { return }
        attempts += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, let self, let user = self.user, let app = self.app else { return }
            self.start(user: user, app: app)
        }
    }

    // MARK: Writes (best effort; errors show in the Sync problem alert)
    func create(_ appointment: Appointment) {
        write { try await self.db.collection("appointments").document(appointment.id.uuidString)
            .setData(Self.data(appointment, creating: true)) }
    }

    func save(_ appointment: Appointment) {
        write { try await self.db.collection("appointments").document(appointment.id.uuidString)
            .setData(Self.data(appointment), merge: true) }
    }

    func save(_ item: InventoryItem) {
        write { try await self.db.collection("inventory").document(item.id.uuidString)
            .setData(Self.data(item), merge: true) }
    }

    func deleteInventory(_ id: UUID) {
        write { try await self.db.collection("inventory").document(id.uuidString).delete() }
    }

    func save(_ receipt: Receipt) {
        write { try await self.db.collection("receipts").document(receipt.id.uuidString)
            .setData(Self.data(receipt), merge: true) }
    }

    /// Saves the receipt and the updated stock levels together.
    func commitReceipt(_ receipt: Receipt, items: [InventoryItem]) {
        write {
            let batch = self.db.batch()
            batch.setData(Self.data(receipt), forDocument: self.db.collection("receipts").document(receipt.id.uuidString))
            for item in items {
                batch.setData(Self.data(item), forDocument: self.db.collection("inventory").document(item.id.uuidString),
                              merge: true)
            }
            try await batch.commit()
        }
    }

    private func write(_ operation: @escaping () async throws -> Void) {
        guard isActive else { return }
        Task { @MainActor in
            do { try await operation() } catch { self.errorMessage = Self.readable(error) }
        }
    }

    // MARK: Encoding
    private static func data(_ a: Appointment, creating: Bool = false) -> [String: Any] {
        var d: [String: Any] = [
            "customerUid": a.customerUid,
            "customerName": a.customerName,
            "customerEmail": a.customerEmail,
            "vehicleTitle": a.vehicleTitle,
            "service": a.service.rawValue,
            "garage": a.garage,
            "date": Timestamp(date: a.date),
            "status": a.status.code,
            "bookedDaysAhead": a.bookedDaysAhead,
            "pastNoShows": a.pastNoShows,
            "isFirstVisit": a.isFirstVisit,
            "notes": a.notes,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        d["assignedStaff"] = a.assignedStaff ?? NSNull()
        if creating { d["createdAt"] = FieldValue.serverTimestamp() }
        return d
    }

    private static func data(_ i: InventoryItem) -> [String: Any] {
        ["name": i.name, "sku": i.sku, "stock": i.stock, "minThreshold": i.minThreshold,
         "usedThisMonth": i.usedThisMonth, "forecastNextMonth": i.forecastNextMonth,
         "unitPrice": i.unitPrice, "updatedAt": FieldValue.serverTimestamp()]
    }

    private static func data(_ r: Receipt) -> [String: Any] {
        let lines = r.lines.map { line -> [String: Any] in
            ["title": line.title, "quantity": line.quantity, "unitPrice": line.unitPrice]
        }
        var d: [String: Any] = [
            "appointmentID": r.appointmentID.uuidString,
            "number": r.number,
            "date": Timestamp(date: r.date),
            "customerUid": r.customerUid,
            "customerName": r.customerName,
            "customerEmail": r.customerEmail,
            "vehicleTitle": r.vehicleTitle,
            "garage": r.garage,
            "mechanic": r.mechanic,
            "lines": lines,
            "notes": r.notes
        ]
        d["sentAt"] = r.sentAt.map { Timestamp(date: $0) } ?? NSNull()
        return d
    }

    // MARK: Decoding
    private static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
    private static func double(_ value: Any?) -> Double { (value as? NSNumber)?.doubleValue ?? 0 }

    private static func parseAppointment(_ doc: QueryDocumentSnapshot) -> Appointment? {
        let d = doc.data()
        guard let id = UUID(uuidString: doc.documentID),
              let service = (d["service"] as? String).flatMap(ServiceKind.init(rawValue:)),
              let status = (d["status"] as? String).flatMap(AppointmentStatus.init(code:)),
              let date = (d["date"] as? Timestamp)?.dateValue() else { return nil }
        return Appointment(id: id,
                           customerName: d["customerName"] as? String ?? "Customer",
                           vehicleTitle: d["vehicleTitle"] as? String ?? "Vehicle",
                           service: service,
                           garage: d["garage"] as? String ?? ownerGarage,
                           date: date,
                           status: status,
                           assignedStaff: d["assignedStaff"] as? String,
                           bookedDaysAhead: int(d["bookedDaysAhead"]),
                           pastNoShows: int(d["pastNoShows"]),
                           isFirstVisit: d["isFirstVisit"] as? Bool ?? false,
                           customerEmail: d["customerEmail"] as? String ?? "",
                           notes: d["notes"] as? String ?? "",
                           customerUid: d["customerUid"] as? String ?? "")
    }

    private static func parseItem(_ doc: QueryDocumentSnapshot) -> InventoryItem? {
        let d = doc.data()
        guard let id = UUID(uuidString: doc.documentID), let name = d["name"] as? String else { return nil }
        return InventoryItem(id: id, name: name, sku: d["sku"] as? String ?? "",
                             stock: int(d["stock"]), minThreshold: int(d["minThreshold"]),
                             usedThisMonth: int(d["usedThisMonth"]), forecastNextMonth: int(d["forecastNextMonth"]),
                             unitPrice: double(d["unitPrice"]))
    }

    private static func parseReceipt(_ doc: QueryDocumentSnapshot) -> Receipt? {
        let d = doc.data()
        guard let id = UUID(uuidString: doc.documentID),
              let appointmentID = (d["appointmentID"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        let lines = (d["lines"] as? [[String: Any]] ?? []).map {
            ReceiptLine(title: $0["title"] as? String ?? "", quantity: max(1, int($0["quantity"])),
                        unitPrice: double($0["unitPrice"]))
        }
        return Receipt(id: id, appointmentID: appointmentID,
                       number: d["number"] as? String ?? "",
                       date: (d["date"] as? Timestamp)?.dateValue() ?? .now,
                       customerName: d["customerName"] as? String ?? "",
                       customerEmail: d["customerEmail"] as? String ?? "",
                       vehicleTitle: d["vehicleTitle"] as? String ?? "",
                       garage: d["garage"] as? String ?? "",
                       mechanic: d["mechanic"] as? String ?? "—",
                       lines: lines,
                       notes: d["notes"] as? String ?? "",
                       sentAt: (d["sentAt"] as? Timestamp)?.dateValue(),
                       customerUid: d["customerUid"] as? String ?? "")
    }

    private static func readable(_ error: Error) -> String {
        (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
            ? "Permission denied. Publish the latest firestore.rules in the Firebase console."
            : error.localizedDescription
    }
}
