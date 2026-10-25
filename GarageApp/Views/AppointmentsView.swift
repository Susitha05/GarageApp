import SwiftUI

struct AppointmentsView: View {
    @Environment(AppState.self) private var app
    @State private var filter: AppointmentStatus? = nil

    private var items: [Appointment] {
        app.appointments
            .filter { filter == nil || $0.status == filter }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Status", selection: $filter) {
                    Text("All").tag(AppointmentStatus?.none)
                    ForEach(AppointmentStatus.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                .pickerStyle(.menu)

                ForEach(items) { a in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(a.customerName).font(.headline)
                            Spacer()
                            StatusBadge(text: a.status.rawValue, color: a.status.color)
                        }
                        Text("\(a.vehicleTitle) • \(a.service.rawValue)").font(.subheadline)
                        Text(a.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                        if let staff = a.assignedStaff {
                            Label("Assigned: \(staff)", systemImage: "person.fill").font(.caption)
                        }
                        if a.noShowRisk > 0.4 {
                            Label("AI no-show risk \(Int(a.noShowRisk * 100))%", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.red)
                        }
                        actions(for: a)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Appointments")
        }
    }

    @ViewBuilder
    private func actions(for a: Appointment) -> some View {
        switch a.status {
        case .pending:
            HStack {
                Button("Accept") { app.setStatus(a.id, .accepted) }.buttonStyle(.borderedProminent)
                Button("Reject", role: .destructive) { app.setStatus(a.id, .rejected) }.buttonStyle(.bordered)
            }
        case .accepted:
            Button("Start service") { app.setStatus(a.id, .inProgress) }.buttonStyle(.bordered)
        case .inProgress:
            Button("Mark complete") { app.setStatus(a.id, .completed) }.buttonStyle(.bordered)
        default:
            EmptyView()
        }
    }
}

#Preview { AppointmentsView().environment(AppState(role: .garageOwner)) }
