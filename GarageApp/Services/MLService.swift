import Foundation
import CoreML

/// Loads the compiled Core ML models bundled with the app (Xcode compiles the
/// .mlmodel files in /MLModels into .mlmodelc automatically) and runs on-device inference.
/// If a model is missing, every call returns nil so callers can use a rule-based fallback.
final class MLService {
    static let shared = MLService()

    private let maintenance = MLService.load("MaintenanceRisk")
    private let noShow = MLService.load("NoShowClassifier")
    private let revenue = MLService.load("RevenueForecaster")

    var maintenanceLoaded: Bool { maintenance != nil }
    var noShowLoaded: Bool { noShow != nil }
    var revenueLoaded: Bool { revenue != nil }

    private static func load(_ name: String) -> MLModel? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try? MLModel(contentsOf: url, configuration: config)
    }

    private func run(_ model: MLModel?, _ inputs: [String: Double]) -> MLFeatureProvider? {
        guard let model, let provider = try? MLDictionaryFeatureProvider(dictionary: inputs) else { return nil }
        return try? model.prediction(from: provider)
    }

    // MARK: Predictive maintenance (classification)
    func maintenanceRisk(mileage: Int, vehicleAge: Int, kmSinceLast: Int, intervalKm: Int) -> (risk: Risk, confidence: Double)? {
        guard let out = run(maintenance, [
            "mileage": Double(mileage), "vehicle_age": Double(vehicleAge),
            "km_since_last": Double(kmSinceLast), "interval_km": Double(intervalKm)
        ]), let label = out.featureValue(for: "risk")?.stringValue,
              let risk = Risk(rawValue: label.capitalized) else { return nil }
        let probs = out.featureValue(for: "classProbability")?.dictionaryValue
        let confidence = probs?[label]?.doubleValue ?? 0.7
        return (risk, confidence)
    }

    // MARK: No-show prediction (classification)
    /// dayOfWeek: Monday = 1 … Sunday = 7
    func noShowProbability(leadTimeDays: Int, dayOfWeek: Int, pastNoShows: Int, firstVisit: Bool) -> Double? {
        guard let out = run(noShow, [
            "lead_time_days": Double(leadTimeDays), "day_of_week": Double(dayOfWeek),
            "past_no_shows": Double(pastNoShows), "is_first_visit": firstVisit ? 1 : 0
        ]), let probs = out.featureValue(for: "classProbability")?.dictionaryValue else { return nil }
        return probs["no_show"]?.doubleValue
    }

    // MARK: Revenue forecast (regression)
    func nextMonthRevenue(monthOfYear: Int, previous: Double) -> Double? {
        guard let out = run(revenue, ["month_of_year": Double(monthOfYear), "prev_revenue": previous]) else { return nil }
        return out.featureValue(for: "revenue")?.doubleValue
    }

    /// Appends `months` forecast points to the actual revenue series.
    func extendRevenue(_ actual: [RevenuePoint], months: Int = 2) -> [RevenuePoint] {
        let names = Calendar.current.shortMonthSymbols
        guard let last = actual.last, let idx = names.firstIndex(of: last.month) else { return actual }
        var result = actual
        var prev = last.amount
        for k in 1...months {
            let m = (idx + k) % 12
            let value = nextMonthRevenue(monthOfYear: m + 1, previous: prev) ?? prev * 1.04
            result.append(RevenuePoint(month: names[m], amount: value, isForecast: true))
            prev = value
        }
        return result
    }
}
