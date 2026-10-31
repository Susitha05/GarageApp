import SwiftUI

/// Log a completed service for a vehicle. Updates history, mileage, predictions and the widget.
struct AddServiceView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    @State private var kind: ServiceKind = .oilChange
    @State private var date = Date()
    @State private var mileage: String
    @State private var cost: String
    @State private var garage = "AutoCare Garage"

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _mileage = State(initialValue: String(vehicle.mileage))
        _cost = State(initialValue: String(Int(ServiceKind.oilChange.basePrice)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Service", selection: $kind) {
                    ForEach(ServiceKind.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                .onChange(of: kind) { _, new in cost = String(Int(new.basePrice)) }
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                TextField("Mileage at service (km)", text: $mileage).keyboardType(.numberPad)
                TextField("Cost (Rs.)", text: $cost).keyboardType(.numberPad)
                TextField("Garage", text: $garage)
                Section("Parts recorded") {
                    Text(kind.partsReplaced.isEmpty ? "None" : kind.partsReplaced.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        app.addRecord(ServiceRecord(vehicleID: vehicle.id, title: kind.rawValue, date: date,
                                                    mileage: Int(mileage) ?? vehicle.mileage,
                                                    cost: Double(cost) ?? kind.basePrice,
                                                    garage: garage, parts: kind.partsReplaced))
                        dismiss()
                    }
                }
            }
        }
    }
}
