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

                let mine = app.isCloud ? app.appointments : app.appointments.filter { $0.customerName == app.userName }
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
                Text("\(service.rawValue) at \(garage), \(slot). A confirmation email is being sent to \(app.email).")
            }
        }
    }

    /// The chosen date combined with the chosen time slot.
    private var scheduledDate: Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        guard let time = formatter.date(from: slot) else { return date }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0,
                                     second: 0, of: date) ?? date
    }

    private func book() {
        let vehicle = app.vehicles.first { $0.id == vehicleID } ?? app.vehicles.first
        let when = scheduledDate
        let lead = max(0, Calendar.current.dateComponents([.day], from: .now, to: when).day ?? 0)
        let appointment = Appointment(customerName: app.userName,
                                      vehicleTitle: vehicle?.title ?? "Vehicle",
                                      service: service, garage: garage,
                                      date: when, status: .pending,
                                      bookedDaysAhead: lead, isFirstVisit: false,
                                      customerEmail: app.email, customerUid: app.userUid)
        app.addAppointment(appointment)      // saved to Firestore, so the garage owner sees it
        app.publishWidgetSnapshot()
        if let g = MockData.garages.first(where: { $0.name == garage }) {
            location.startGeofence(id: g.name, center: g.coordinate)   // arrival detection
        }

        // Confirmation email to the customer (needs the Firebase email extension, see README).
        let mail = EmailTemplates.bookingReceived(appointment)
        let address = app.email
        Task { _ = await EmailService.queue(to: address, subject: mail.subject, text: mail.body) }
        confirmed = true
    }
}

#Preview { ScheduleServiceView().environment(AppState(role: .customer)) }
