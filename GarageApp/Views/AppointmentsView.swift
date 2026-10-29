import SwiftUI

private enum AppointmentSheet: Identifiable {
    case edit(Appointment)
    case receipt(UUID)
    case email(UUID)

    var id: String {
        switch self {
        case .edit(let a): "edit-\(a.id.uuidString)"
        case .receipt(let id): "receipt-\(id.uuidString)"
        case .email(let id): "email-\(id.uuidString)"
        }
    }
}

struct AppointmentsView: View {
    @Environment(AppState.self) private var app
    @State private var filter: AppointmentStatus? = nil
    @State private var sheet: AppointmentSheet?

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

                ForEach(items) { card($0) }
            }
            .navigationTitle("Appointments")
            .sheet(item: $sheet) { item in
                switch item {
                case .edit(let a): AppointmentEditView(appointment: a)
                case .receipt(let id): ReceiptBuilderView(appointmentID: id)
                case .email(let id): EmailCustomerSheet(appointmentID: id)
                }
            }
        }
    }

    private func card(_ a: Appointment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(a.customerName).font(.headline)
                Spacer()
                StatusBadge(text: a.status.rawValue, color: a.status.color)
            }
            Text("\(a.vehicleTitle) • \(a.service.rawValue)").font(.subheadline)
            Text(a.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundStyle(.secondary)
            if !a.notes.isEmpty {
                Label(a.notes, systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
            }
            if a.noShowRisk > 0.4 && a.status != .completed {
                Label("AI no-show risk \(Int(a.noShowRisk * 100))%", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }

            workflowButtons(a)

            HStack(spacing: 8) {
                Menu {
                    Button("Unassigned") { app.assign(a.id, to: nil) }
                    Divider()
                    ForEach(app.staff) { s in
                        Button { app.assign(a.id, to: s.name) } label: {
                            if a.assignedStaff == s.name {
                                Label("\(s.name) • \(s.assignedJobs) active", systemImage: "checkmark")
                            } else {
                                Text("\(s.name) • \(s.assignedJobs) active")
                            }
                        }
                    }
                } label: {
                    Label(a.assignedStaff?.components(separatedBy: " ").first ?? "Assign", systemImage: "person.badge.plus")
                }
                Button { sheet = .edit(a) } label: { Label("Edit", systemImage: "pencil") }
                Button { sheet = .email(a.id) } label: { Label("Email", systemImage: "envelope") }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func workflowButtons(_ a: Appointment) -> some View {
        switch a.status {
        case .pending:
            HStack {
                Button("Accept") { app.setStatus(a.id, .accepted) }.buttonStyle(.borderedProminent)
                Button("Reject", role: .destructive) { app.setStatus(a.id, .rejected) }.buttonStyle(.bordered)
            }
        case .accepted:
            Button("Start service") { app.setStatus(a.id, .inProgress) }.buttonStyle(.bordered)
        case .inProgress:
            Button("Mark complete") {
                app.setStatus(a.id, .completed)
                sheet = .receipt(a.id)          // go straight to the receipt
            }
            .buttonStyle(.borderedProminent)
        case .completed:
            Button { sheet = .receipt(a.id) } label: {
                Label(app.receipt(for: a.id) == nil ? "Create receipt" : "View / send receipt", systemImage: "doc.text")
            }
            .buttonStyle(.borderedProminent)
        case .rejected:
            EmptyView()
        }
    }
}

#Preview { AppointmentsView().environment(AppState(role: .garageOwner)) }
