import SwiftUI

/// Add a vehicle, or edit an existing one when `editing` is passed.
struct AddVehicleView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let editing: Vehicle?
    @State private var registration: String
    @State private var make: String
    @State private var model: String
    @State private var year: Int
    @State private var mileage: String

    init(editing: Vehicle? = nil) {
        self.editing = editing
        _registration = State(initialValue: editing?.registration ?? "")
        _make = State(initialValue: editing?.make ?? "")
        _model = State(initialValue: editing?.model ?? "")
        _year = State(initialValue: editing?.year ?? 2020)
        _mileage = State(initialValue: editing.map { String($0.mileage) } ?? "")
    }

    private var isValid: Bool { !registration.isEmpty && !make.isEmpty && !model.isEmpty && Int(mileage) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Registration number", text: $registration).textInputAutocapitalization(.characters)
                }
                Section("Details") {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    Stepper("Year: \(String(year))", value: $year, in: 1990...2030)
                    TextField("Mileage (km)", text: $mileage).keyboardType(.numberPad)
                }
            }
            .navigationTitle(editing == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if var vehicle = editing {
            vehicle.registration = registration
            vehicle.make = make
            vehicle.model = model
            vehicle.year = year
            vehicle.mileage = Int(mileage) ?? vehicle.mileage
            app.updateVehicle(vehicle)
        } else {
            app.addVehicle(Vehicle(registration: registration, make: make, model: model,
                                   year: year, mileage: Int(mileage) ?? 0))
        }
        dismiss()
    }
}

#Preview("Add") { AddVehicleView().environment(AppState(role: .customer)) }
#Preview("Edit") { AddVehicleView(editing: MockData.vehicles[0]).environment(AppState(role: .customer)) }
