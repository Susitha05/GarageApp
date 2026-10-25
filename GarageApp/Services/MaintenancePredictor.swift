import Foundation

/// Uses the Core ML `MaintenanceRisk` model when bundled; otherwise falls back to a simple rule.
struct MaintenancePredictor {
    private let intervals: [(part: String, km: Int)] = [
        ("Engine Oil", 5_000), ("Air Filter", 15_000), ("Brake Pads", 30_000),
        ("Tyres", 40_000), ("Battery", 50_000)
    ]

    func predict(for vehicle: Vehicle, records: [ServiceRecord]) -> [PredictedMaintenance] {
        let mine = records.filter { $0.vehicleID == vehicle.id }
        let age = max(0, Calendar.current.component(.year, from: .now) - vehicle.year)
        var out: [PredictedMaintenance] = []

        for item in intervals {
            let last = mine.filter { $0.parts.contains(item.part) }.map(\.mileage).max() ?? 0
            let since = max(0, vehicle.mileage - last)
            let due = last + item.km - vehicle.mileage

            var risk: Risk = due < 0 ? .high : (due < item.km / 5 ? .medium : .low)
            var confidence = min(0.95, 0.6 + Double(mine.count) * 0.07)

            if let r = MLService.shared.maintenanceRisk(mileage: vehicle.mileage, vehicleAge: age,
                                                         kmSinceLast: since, intervalKm: item.km) {
                risk = r.risk
                confidence = r.confidence
            }
            out.append(PredictedMaintenance(part: item.part, dueInKm: due, confidence: confidence, risk: risk))
        }
        return out.sorted { $0.dueInKm < $1.dueInKm }
    }
}
