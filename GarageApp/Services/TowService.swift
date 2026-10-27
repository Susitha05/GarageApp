import Foundation
import CoreLocation
import FirebaseCore
import FirebaseFirestore

/// Tow requests shared between customers and drivers through Firestore (`towRequests` collection).
/// When Firebase isn't configured (SwiftUI previews) it runs on local sample data instead.
@Observable
final class TowService {
    static let shared = TowService()

    var openRequests: [TowRequest] = []        // driver: status == requested
    var driverJobs: [TowRequest] = []          // driver: assigned to me
    var customerRequests: [TowRequest] = []    // customer: my requests
    var dismissedIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "dismissedTowIDs") ?? [])
    var selectedJobID: String?
    var driverListenError: String?
    var errorMessage: String?

    @ObservationIgnored private var listeners: [ListenerRegistration] = []
    @ObservationIgnored private var lastCustomerPush = Date.distantPast
    @ObservationIgnored private var lastDriverPush: [String: Date] = [:]
    @ObservationIgnored private var retryTask: Task<Void, Never>?

    var usesFirebase: Bool { FirebaseApp.app() != nil }

    init() {
        if FirebaseApp.app() == nil { openRequests = MockData.towRequests }
    }

    private var collection: CollectionReference { Firestore.firestore().collection("towRequests") }

    var customerRequest: TowRequest? {
        customerRequests
            .filter { $0.status != .cancelled && !dismissedIDs.contains($0.id) }
            .max { $0.createdAt < $1.createdAt }
    }

    var activeDriverJobs: [TowRequest] {
        driverJobs.filter { $0.status.isActive }.sorted { $0.createdAt < $1.createdAt }
    }

    /// The job shown on the Active tab (the selected one, otherwise the oldest).
    var activeDriverJob: TowRequest? {
        let jobs = activeDriverJobs
        return jobs.first { $0.id == selectedJobID } ?? jobs.first
    }

    func select(_ id: String) { selectedJobID = id }

    func dismiss(_ id: String) {
        dismissedIDs.insert(id)
        UserDefaults.standard.set(Array(dismissedIDs), forKey: "dismissedTowIDs")
    }

    // MARK: Listeners
    func listenAsCustomer(uid: String) {
        guard usesFirebase, uid != "dev" else { return }
        stop()
        listeners.append(collection.whereField("customerUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { self.errorMessage = error.localizedDescription; return }
                self.customerRequests = snapshot?.documents.compactMap(Self.parse) ?? []
            })
    }

    func listenAsDriver(uid: String) {
        guard usesFirebase, uid != "dev" else { return }
        stop()
        driverListenError = nil

        listeners.append(collection.whereField("status", isEqualTo: TowStatus.requested.code)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { self.listenerFailed(error, uid: uid); return }
                self.driverListenError = nil
                self.openRequests = (snapshot?.documents.compactMap(Self.parse) ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
            })
        listeners.append(collection.whereField("driverUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { self.listenerFailed(error, uid: uid); return }
                self.driverListenError = nil
                self.driverJobs = snapshot?.documents.compactMap(Self.parse) ?? []
            })
    }

    /// Firestore ends a listener after an error, so restart it automatically after a short delay.
    private func listenerFailed(_ error: Error, uid: String) {
        driverListenError = readable(error)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, let self, self.driverListenError != nil else { return }
            self.listenAsDriver(uid: uid)
        }
    }

    func stop() {
        guard usesFirebase else { return }
        retryTask?.cancel()
        retryTask = nil
        driverListenError = nil
        selectedJobID = nil
        listeners.forEach { $0.remove() }
        listeners = []
        openRequests = []
        driverJobs = []
        customerRequests = []
    }

    // MARK: Customer actions
    private static let devMessage = "Skip-login mode has no account, so live tow requests are unavailable. Sign in with a real account."

    func requestTow(user: AppUser, vehicleTitle: String, coordinate: CLLocationCoordinate2D, address: String) async {
        if usesFirebase, user.uid == "dev" { errorMessage = Self.devMessage; return }
        guard usesFirebase else {
            customerRequests.append(TowRequest(customerUid: user.uid, customerName: user.name, vehicleTitle: vehicleTitle,
                                               address: address, latitude: coordinate.latitude,
                                               longitude: coordinate.longitude, status: .requested))
            return
        }
        do {
            _ = try await collection.addDocument(data: [
                "customerUid": user.uid,
                "customerName": user.name,
                "vehicleTitle": vehicleTitle,
                "address": address,
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "status": TowStatus.requested.code,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = readable(error)
        }
    }

    func cancel(_ request: TowRequest) async {
        guard usesFirebase else {
            if let i = customerRequests.firstIndex(where: { $0.id == request.id }) { customerRequests[i].status = .cancelled }
            return
        }
        do {
            try await collection.document(request.id).updateData([
                "status": TowStatus.cancelled.code,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = readable(error)
        }
    }

    /// Streams the customer's live position to the driver (max every 5 s).
    func pushCustomerLocation(_ request: TowRequest, coordinate: CLLocationCoordinate2D) async {
        guard usesFirebase, request.status.isActive,
              Date().timeIntervalSince(lastCustomerPush) > 5 else { return }
        lastCustomerPush = Date()
        try? await collection.document(request.id).updateData([
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: Driver actions
    func accept(_ request: TowRequest, driver: AppUser, coordinate: CLLocationCoordinate2D) async {
        if usesFirebase, driver.uid == "dev" { errorMessage = Self.devMessage; return }
        guard usesFirebase else {
            openRequests.removeAll { $0.id == request.id }
            var job = request
            job.status = .accepted
            job.driverUid = driver.uid
            job.driverName = driver.name
            driverJobs.append(job)
            return
        }
        do {
            try await collection.document(request.id).updateData([
                "status": TowStatus.accepted.code,
                "driverUid": driver.uid,
                "driverName": driver.name,
                "driverLatitude": coordinate.latitude,
                "driverLongitude": coordinate.longitude,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            if activeDriverJob == nil { selectedJobID = request.id }
        } catch {
            errorMessage = (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
                ? "This job is no longer available (another driver may have taken it)."
                : readable(error)
        }
    }

    func advance(_ request: TowRequest) async {
        guard let next = request.status.next else { return }
        guard usesFirebase else {
            if let i = driverJobs.firstIndex(where: { $0.id == request.id }) { driverJobs[i].status = next }
            return
        }
        do {
            try await collection.document(request.id).updateData([
                "status": next.code,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = readable(error)
        }
    }

    /// Streams the driver's live position to the customer (max every 5 s).
    func pushDriverLocation(_ request: TowRequest, coordinate: CLLocationCoordinate2D) async {
        guard usesFirebase, request.status.isActive,
              Date().timeIntervalSince(lastDriverPush[request.id] ?? .distantPast) > 5 else { return }
        lastDriverPush[request.id] = Date()
        try? await collection.document(request.id).updateData([
            "driverLatitude": coordinate.latitude,
            "driverLongitude": coordinate.longitude,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: Helpers
    private func readable(_ error: Error) -> String {
        (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
            ? "Permission denied. Publish the latest firestore.rules in the Firebase console."
            : error.localizedDescription
    }

    private static func parse(_ doc: QueryDocumentSnapshot) -> TowRequest? {
        let d = doc.data()
        guard let code = d["status"] as? String, let status = TowStatus(code: code) else { return nil }
        return TowRequest(
            id: doc.documentID,
            customerUid: d["customerUid"] as? String ?? "",
            customerName: d["customerName"] as? String ?? "Customer",
            vehicleTitle: d["vehicleTitle"] as? String ?? "Vehicle",
            address: d["address"] as? String ?? "",
            latitude: d["latitude"] as? Double ?? 0,
            longitude: d["longitude"] as? Double ?? 0,
            status: status,
            driverUid: d["driverUid"] as? String,
            driverName: d["driverName"] as? String,
            driverLatitude: d["driverLatitude"] as? Double,
            driverLongitude: d["driverLongitude"] as? Double,
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date())
    }
}
