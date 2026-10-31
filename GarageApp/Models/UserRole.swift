import SwiftUI
import CoreLocation

enum UserRole: String, CaseIterable, Identifiable {
    case customer = "Customer"
    case garageOwner = "Garage Owner"
    case towDriver = "Tow Driver"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .customer: "car.fill"
        case .garageOwner: "wrench.and.screwdriver.fill"
        case .towDriver: "truck.box.fill"
        }
    }
    var blurb: String {
        switch self {
        case .customer: "Track vehicle health, book services, request towing"
        case .garageOwner: "Appointments, inventory, forecasts, staff"
        case .towDriver: "Accept jobs, navigate, update status"
        }
    }
}

enum Risk: String {
    case low = "Low", medium = "Medium", high = "High"
    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

// Codable so vehicles can be saved to the phone.
struct Vehicle: Identifiable, Codable {
    var id = UUID()
    var registration: String
    var make: String
    var model: String
    var year: Int
    var mileage: Int
    var title: String { "\(year) \(make) \(model)" }
}

enum ServiceKind: String, CaseIterable, Identifiable {
    case oilChange = "Oil Change"
    case brakeService = "Brake Service"
    case tireRotation = "Tyre Rotation"
    case batteryCheck = "Battery Check"
    case acService = "A/C Service"
    case fullService = "Full Service"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .oilChange: "drop.fill"
        case .brakeService: "exclamationmark.octagon.fill"
        case .tireRotation: "circle.dotted"
        case .batteryCheck: "bolt.car.fill"
        case .acService: "snowflake"
        case .fullService: "checkmark.seal.fill"
        }
    }
}

extension ServiceKind {
    /// Part names must match the names used in MaintenancePredictor exactly.
    var partsReplaced: [String] {
        switch self {
        case .oilChange: ["Engine Oil"]
        case .brakeService: ["Brake Pads"]
        case .tireRotation: ["Tyres"]
        case .batteryCheck: ["Battery"]
        case .acService: []
        case .fullService: ["Engine Oil", "Air Filter"]
        }
    }
}

// Codable so service history can be saved to the phone.
struct ServiceRecord: Identifiable, Codable {
    var id = UUID()
    var vehicleID: UUID
    var title: String
    var date: Date
    var mileage: Int
    var cost: Double
    var garage: String
    var parts: [String]
    var appointmentID: UUID? = nil     // links a record to the booking that created it
}

struct PredictedMaintenance: Identifiable {
    var id = UUID()
    var part: String
    var dueInKm: Int
    var confidence: Double
    var risk: Risk
}

enum AppointmentStatus: String, CaseIterable, Identifiable {
    case pending = "Pending", accepted = "Accepted", inProgress = "In Progress"
    case completed = "Completed", rejected = "Rejected"
    var id: String { rawValue }

    /// Value stored in Firestore.
    var code: String {
        switch self {
        case .pending: "pending"
        case .accepted: "accepted"
        case .inProgress: "inProgress"
        case .completed: "completed"
        case .rejected: "rejected"
        }
    }
    init?(code: String) {
        guard let value = Self.allCases.first(where: { $0.code == code }) else { return nil }
        self = value
    }
    var color: Color {
        switch self {
        case .pending: .orange
        case .accepted: .blue
        case .inProgress: .purple
        case .completed: .green
        case .rejected: .red
        }
    }
}

struct Appointment: Identifiable {
    var id = UUID()
    var customerName: String
    var vehicleTitle: String
    var service: ServiceKind
    var garage: String = "AutoCare Garage"
    var date: Date
    var status: AppointmentStatus
    var assignedStaff: String? = nil
    var noShowRisk: Double = 0.1
    var bookedDaysAhead: Int = 2
    var pastNoShows: Int = 0
    var isFirstVisit: Bool = false
    var customerEmail: String = ""
    var notes: String = ""
    var customerUid: String = ""
}

struct GarageInfo: Identifiable {
    var id: String { name }
    var name: String
    var latitude: Double
    var longitude: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

struct InventoryItem: Identifiable {
    var id = UUID()
    var name: String
    var sku: String
    var stock: Int
    var minThreshold: Int
    var usedThisMonth: Int
    var forecastNextMonth: Int
    var unitPrice: Double = 0
    var isLow: Bool { stock <= minThreshold }
}

struct StaffMember: Identifiable {
    var id = UUID()
    var name: String
    var role: String
    var assignedJobs: Int
    var completedJobs: Int
    var load: Double { min(1, Double(assignedJobs) / 8.0) }
}

enum TowStatus: String, CaseIterable {
    case requested = "Requested", accepted = "Accepted", enRoute = "En Route"
    case arrived = "Arrived", towing = "Towing", completed = "Completed", cancelled = "Cancelled"

    /// Value stored in Firestore.
    var code: String {
        switch self {
        case .requested: "requested"
        case .accepted: "accepted"
        case .enRoute: "enRoute"
        case .arrived: "arrived"
        case .towing: "towing"
        case .completed: "completed"
        case .cancelled: "cancelled"
        }
    }
    init?(code: String) {
        guard let s = Self.allCases.first(where: { $0.code == code }) else { return nil }
        self = s
    }

    var next: TowStatus? {
        switch self {
        case .requested: .accepted
        case .accepted: .enRoute
        case .enRoute: .arrived
        case .arrived: .towing
        case .towing: .completed
        case .completed, .cancelled: nil
        }
    }
    var isActive: Bool { self != .completed && self != .cancelled }
    var color: Color {
        switch self {
        case .requested: .orange
        case .accepted, .enRoute: .blue
        case .arrived, .towing: .purple
        case .completed: .green
        case .cancelled: .gray
        }
    }
}

struct TowRequest: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var customerUid: String = ""
    var customerName: String
    var vehicleTitle: String
    var address: String
    var latitude: Double
    var longitude: Double
    var status: TowStatus
    var driverUid: String? = nil
    var driverName: String? = nil
    var driverLatitude: Double? = nil
    var driverLongitude: Double? = nil
    var createdAt: Date = .now

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var driverCoordinate: CLLocationCoordinate2D? {
        guard let lat = driverLatitude, let lon = driverLongitude else { return nil }
        return .init(latitude: lat, longitude: lon)
    }
}

struct ExpenseEntry: Identifiable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var category: String
}

struct RevenuePoint: Identifiable {
    var id = UUID()
    var month: String
    var amount: Double
    var isForecast: Bool = false
}

struct AppNotification: Identifiable {
    var id = UUID()
    var title: String
    var body: String
    var date: Date
    var icon: String
}

struct Anomaly: Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var risk: Risk
}

func rs(_ value: Double) -> String {
    "Rs. " + value.formatted(.number.precision(.fractionLength(0)))
}

extension ServiceKind {
    /// Default labour / service charge (LKR) pre-filled on receipts.
    var basePrice: Double {
        switch self {
        case .oilChange: 3_500
        case .brakeService: 8_500
        case .tireRotation: 2_500
        case .batteryCheck: 1_500
        case .acService: 6_000
        case .fullService: 18_000
        }
    }
}

struct ReceiptLine: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var quantity: Int
    var unitPrice: Double
    var amount: Double { Double(quantity) * unitPrice }
}

struct Receipt: Identifiable, Equatable {
    var id = UUID()
    var appointmentID: UUID
    var number: String
    var date: Date = .now
    var customerName: String
    var customerEmail: String
    var vehicleTitle: String
    var garage: String
    var mechanic: String
    var lines: [ReceiptLine]
    var notes: String = ""
    var sentAt: Date? = nil
    var customerUid: String = ""
    var total: Double { lines.reduce(0) { $0 + $1.amount } }
}
