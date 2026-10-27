import SwiftUI

struct ScheduleServiceView: View {
    @Environment(AppState.self) private var app
    private let location = LocationManager.shared

    @State private var vehicleID: UUID?
    @State private var service: ServiceKind = .oilChange
    @State private var garage = MockData.garages[0].name
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var slot = "10:00 AM"
    @State private var confirmed = false

    private let slots = ["09:00 AM", "10:00 AM", "11:30 AM", "01:00 PM", "03:00 PM", "04:30 PM"]

    private func distanceText(_ g: GarageInfo) -> String {
        guard let km = location.distanceKm(to: g.coordinate) else { return "" }
        return String(format: " • %.1f km", km)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let arrived = location.arrivedRegionID {
                    Section {
                        Label("You've arrived at \(arrived)", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
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
                Section {
                    Picker("Garage", selection: $garage) {
                        ForEach(MockData.garages) { g in
                            Text(g.name + distanceText(g)).tag(g.name)
                        }
                    }
                } header: {
                    Text("3. Garage")
                } footer: {
                    Text(location.isLive ? "Distances from your current location." : "Enable location to see distances.")
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
                        .disabled(app.vehicles.isEmpty)
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
            .task { location.start() }
            .onAppear { if vehicleID == nil { vehicleID = app.vehicles.first?.id } }
            .alert("Booking requested", isPresented: $confirmed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(service.rawValue) at \(garage), \(slot). We'll let you know when you arrive.")
            }
        }
    }

    private func book() {
        let vehicle = app.vehicles.first { $0.id == vehicleID } ?? app.vehicles.first
        let lead = max(0, Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0)
        app.appointments.append(Appointment(customerName: app.userName,
                                            vehicleTitle: vehicle?.title ?? "Vehicle",
                                            service: service, garage: garage,
                                            date: date, status: .pending,
                                            bookedDaysAhead: lead, isFirstVisit: false))
        app.refreshNoShowRisk()
        app.publishWidgetSnapshot()
        if let g = MockData.garages.first(where: { $0.name == garage }) {
            location.startGeofence(id: g.name, center: g.coordinate)   // arrival detection
        }
        confirmed = true
    }
}

#Preview { ScheduleServiceView().environment(AppState(role: .customer)) }
