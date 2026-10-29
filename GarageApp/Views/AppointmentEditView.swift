import SwiftUI

/// Reschedule, change the service or status, assign a mechanic and add notes.
struct AppointmentEditView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let original: Appointment
    @State private var date: Date
    @State private var service: ServiceKind
    @State private var status: AppointmentStatus
    @State private var mechanic: String        // "" = unassigned
    @State private var email: String
    @State private var notes: String

    init(appointment: Appointment) {
        original = appointment
        _date = State(initialValue: appointment.date)
        _service = State(initialValue: appointment.service)
        _status = State(initialValue: appointment.status)
        _mechanic = State(initialValue: appointment.assignedStaff ?? "")
        _email = State(initialValue: appointment.customerEmail)
        _notes = State(initialValue: appointment.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    LabeledContent("Name", value: original.customerName)
                    LabeledContent("Vehicle", value: original.vehicleTitle)
                    TextField("Customer email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Job") {
                    Picker("Service", selection: $service) {
                        ForEach(ServiceKind.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                    }
                    DatePicker("Date & time", selection: $date)
                    Picker("Status", selection: $status) {
                        ForEach(AppointmentStatus.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section {
                    Picker("Assigned to", selection: $mechanic) {
                        Text("Unassigned").tag("")
                        ForEach(app.staff) { Text("\($0.name) • \($0.assignedJobs) active").tag($0.name) }
                    }
                } header: {
                    Text("Mechanic")
                } footer: {
                    Text("The mechanic's workload on the Insights tab updates automatically.")
                }
                Section("Notes") {
                    TextField("Notes for the mechanic", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle("Edit Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        var a = original
        a.date = date
        a.service = service
        a.status = status
        a.assignedStaff = mechanic.isEmpty ? nil : mechanic
        a.customerEmail = email.trimmingCharacters(in: .whitespaces)
        a.notes = notes
        app.updateAppointment(a)
        dismiss()
    }
}

#Preview { AppointmentEditView(appointment: MockData.appointments[0]).environment(AppState(role: .garageOwner)) }
