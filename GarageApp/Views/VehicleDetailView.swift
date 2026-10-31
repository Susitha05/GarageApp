import SwiftUI

/// Digital vehicle health timeline: past services + predicted maintenance. Edit / delete from the ••• menu.
struct VehicleDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let vehicleID: UUID
    @State private var showEdit = false
    @State private var showAddService = false
    @State private var confirmDelete = false
    private let predictor = MaintenancePredictor()

    private var vehicle: Vehicle? { app.vehicles.first { $0.id == vehicleID } }

    var body: some View {
        Group {
            if let vehicle {
                content(vehicle)
            } else {
                ContentUnavailableView("Vehicle removed", systemImage: "car")
            }
        }
        .navigationTitle("Vehicle Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let vehicle {
                Menu {
                    Button { showAddService = true } label: { Label("Log a service", systemImage: "plus.circle") }
                    Button { showEdit = true } label: { Label("Edit vehicle", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete vehicle", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Vehicle options for \(vehicle.title)")
            }
        }
        .sheet(isPresented: $showEdit) {
            if let vehicle { AddVehicleView(editing: vehicle) }
        }
        .sheet(isPresented: $showAddService) {
            if let vehicle { AddServiceView(vehicle: vehicle) }
        }
        .confirmationDialog("Delete this vehicle?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                app.removeVehicle(vehicleID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its service history will be removed too.")
        }
    }

    private func content(_ vehicle: Vehicle) -> some View {
        let history = app.records.filter { $0.vehicleID == vehicle.id }.sorted { $0.date > $1.date }
        let predictions = predictor.predict(for: vehicle, records: app.records)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Card {
                    Text(vehicle.title).font(.title3.bold())
                    Text(vehicle.registration).foregroundStyle(.secondary)
                    Label("\(vehicle.mileage.formatted()) km", systemImage: "speedometer")
                }

                SectionTitle("Predicted maintenance")
                Label(MLService.shared.maintenanceLoaded ? "On-device Core ML model" : "Rule-based fallback (model not bundled)",
                      systemImage: MLService.shared.maintenanceLoaded ? "cpu" : "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary)
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
                if history.isEmpty { Text("No records yet.").foregroundStyle(.secondary) }
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
    }
}

#Preview {
    NavigationStack { VehicleDetailView(vehicleID: MockData.vehicles[0].id) }
        .environment(AppState(role: .customer))
}
