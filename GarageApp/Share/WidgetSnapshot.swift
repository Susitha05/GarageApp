import Foundation
import WidgetKit


enum AppGroup {
    /// Must match the App Group capability enabled on both targets.
    static let id = "group.com.example.smartgarage"
}

struct WidgetSnapshot: Codable, Equatable {
    var vehicleName: String
    var topPart: String
    var dueInKm: Int
    var risk: String            // "Low" | "Medium" | "High"
    var nextAppointmentTitle: String?
    var nextAppointmentDate: Date?
    var towStatus: String?
    var updated: Date

    static let sample = WidgetSnapshot(
        vehicleName: "2016 Toyota Axio", topPart: "Air Filter", dueInKm: -63_400, risk: "High",
        nextAppointmentTitle: "Oil Change • AutoCare Garage",
        nextAppointmentDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
        towStatus: nil, updated: .now)
}

enum WidgetSnapshotStore {
    private static let key = "widget.snapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: AppGroup.id),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: AppGroup.id),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
