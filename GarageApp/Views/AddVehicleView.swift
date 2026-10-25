import SwiftUI

struct AddVehicleView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var registration = ""
    @State private var make = ""
    @State private var model = ""
    @State private var year = 2020
    @State private var mileage = ""

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
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        app.vehicles.append(Vehicle(registration: registration, make: make, model: model,
                                                    year: year, mileage: Int(mileage) ?? 0))
                        app.publishWidgetSnapshot()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

#Preview { AddVehicleView().environment(AppState(role: .customer)) }
