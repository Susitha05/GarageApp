import Foundation

/// Rule-based stand-in for the Core ML model. Keep this signature and swap the body
/// for a Create ML–trained model once training data is ready.
struct MaintenancePredictor {
    private let intervals: [(part: String, km: Int)] = [
        ("Engine Oil", 5_000), ("Air Filter", 15_000), ("Brake Pads", 30_000),
        ("Tyres", 40_000), ("Battery", 50_000)
    ]

    func predict(for vehicle: Vehicle, records: [ServiceRecord]) -> [PredictedMaintenance] {
        var out: [PredictedMaintenance] = []
        let mine = records.filter { $0.vehicleID == vehicle.id }
        for item in intervals {
            let last = mine.filter { $0.parts.contains(item.part) }.map(\.mileage).max() ?? 0
            let due = last + item.km - vehicle.mileage
            let risk: Risk = due < 0 ? .high : (due < item.km / 5 ? .medium : .low)
            let confidence = min(0.95, 0.6 + Double(mine.count) * 0.07)
            out.append(PredictedMaintenance(part: item.part, dueInKm: due, confidence: confidence, risk: risk))
        }
        return out.sorted { $0.dueInKm < $1.dueInKm }
    }
}
