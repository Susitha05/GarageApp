import SwiftUI

/// Digital vehicle health timeline: past services + predicted maintenance.
struct VehicleDetailView: View {
    @Environment(AppState.self) private var app
    let vehicle: Vehicle
    private let predictor = MaintenancePredictor()

    private var history: [ServiceRecord] {
        app.records.filter { $0.vehicleID == vehicle.id }.sorted { $0.date > $1.date }
    }
    private var predictions: [PredictedMaintenance] {
        predictor.predict(for: vehicle, records: app.records)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Card {
                    Text(vehicle.title).font(.title3.bold())
                    Text(vehicle.registration).foregroundStyle(.secondary)
                    Label("\(vehicle.mileage.formatted()) km", systemImage: "speedometer")
                }

                SectionTitle("Predicted (on-device AI)")
                ForEach(predictions) { p in
                    HStack {
                        Circle().fill(p.risk.color).frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(p.part).font(.subheadline.weight(.semibold))
                            Text(p.dueInKm < 0 ? "Overdue by \(-p.dueInKm) km" : "In ~\(p.dueInKm) km")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(p.confidence * 100))%").font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                SectionTitle("Service history")
                if history.isEmpty {
                    Text("No records yet.").foregroundStyle(.secondary)
                }
                ForEach(history) { r in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).font(.subheadline.weight(.semibold))
                            Text("\(r.date.formatted(date: .abbreviated, time: .omitted)) • \(r.mileage.formatted()) km")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(r.garage) • \(rs(r.cost))").font(.caption)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
        }
        .navigationTitle("Vehicle Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VehicleDetailView(vehicle: MockData.vehicles[0])
    }
    .environment(AppState(role: .customer))
}
