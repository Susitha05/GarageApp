import SwiftUI

struct ScheduleServiceView: View {
    @Environment(AppState.self) private var app

    @State private var vehicleID: UUID?
    @State private var service: ServiceKind = .oilChange
    @State private var garage = "AutoCare Garage"
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var slot = "10:00 AM"
    @State private var confirmed = false

    private let garages = ["AutoCare Garage", "Power Motors", "Negombo Auto Works"]
    private let slots = ["09:00 AM", "10:00 AM", "11:30 AM", "01:00 PM", "03:00 PM", "04:30 PM"]

    var body: some View {
        NavigationStack {
            Form {
                Section("1. Vehicle") {
                    Picker("Vehicle", selection: $vehicleID) {
                        ForEach(app.vehicles) { Text($0.title).tag(Optional($0.id)) }
                    }
                }
                Section("2. Service") {
                    Picker("Service", selection: $service) {
                        ForEach(ServiceKind.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                    }
                }
                Section("3. Garage") {
                    Picker("Garage", selection: $garage) {
                        ForEach(garages, id: \.self) { Text($0) }
                    }
                }
                Section("4. Date & time") {
                    DatePicker("Date", selection: $date, in: Date.now..., displayedComponents: .date)
                    Picker("Time slot", selection: $slot) {
                        ForEach(slots, id: \.self) { Text($0) }
                    }
                }
                Section {
                    Button("Confirm booking") { book() }
                        .frame(maxWidth: .infinity)
                        .disabled(vehicleID == nil && app.vehicles.isEmpty)
                }

                let mine = app.appointments.filter { $0.customerName == app.userName }
                if !mine.isEmpty {
                    Section("My appointments") {
                        ForEach(mine) { a in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(a.service.rawValue).font(.subheadline.weight(.semibold))
                                    Text("\(a.garage) • \(a.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(text: a.status.rawValue, color: a.status.color)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Book a Service")
            .onAppear { if vehicleID == nil { vehicleID = app.vehicles.first?.id } }
            .alert("Booking requested", isPresented: $confirmed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(service.rawValue) at \(garage), \(slot). You'll be notified once the garage confirms.")
            }
        }
    }

    private func book() {
        let vehicle = app.vehicles.first { $0.id == vehicleID } ?? app.vehicles.first
        app.appointments.append(Appointment(customerName: app.userName,
                                            vehicleTitle: vehicle?.title ?? "Vehicle",
                                            service: service, garage: garage,
                                            date: date, status: .pending))
        confirmed = true
    }
}

#Preview { ScheduleServiceView().environment(AppState(role: .customer)) }
