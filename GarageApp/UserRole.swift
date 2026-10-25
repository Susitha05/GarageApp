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

struct Vehicle: Identifiable {
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

struct ServiceRecord: Identifiable {
    var id = UUID()
    var vehicleID: UUID
    var title: String
    var date: Date
    var mileage: Int
    var cost: Double
    var garage: String
    var parts: [String]
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
}

struct InventoryItem: Identifiable {
    var id = UUID()
    var name: String
    var sku: String
    var stock: Int
    var minThreshold: Int
    var usedThisMonth: Int
    var forecastNextMonth: Int
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
    case arrived = "Arrived", towing = "Towing", completed = "Completed"

    var next: TowStatus? {
        guard let i = Self.allCases.firstIndex(of: self), i + 1 < Self.allCases.count else { return nil }
        return Self.allCases[i + 1]
    }
    var color: Color {
        switch self {
        case .requested: .orange
        case .accepted, .enRoute: .blue
        case .arrived, .towing: .purple
        case .completed: .green
        }
    }
}

struct TowRequest: Identifiable {
    var id = UUID()
    var customerName: String
    var vehicleTitle: String
    var address: String
    var latitude: Double
    var longitude: Double
    var distanceKm: Double
    var status: TowStatus
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
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
