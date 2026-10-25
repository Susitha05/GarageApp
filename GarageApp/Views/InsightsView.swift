import SwiftUI

/// No-show predictions, repair anomalies and staff workload balancing.
struct InsightsView: View {
    @Environment(AppState.self) private var app

    private var risky: [Appointment] {
        app.appointments.filter { $0.noShowRisk > 0.4 && $0.status != .completed && $0.status != .rejected }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("No-show predictions") {
                    if risky.isEmpty { Text("No high-risk bookings.").foregroundStyle(.secondary) }
                    ForEach(risky) { a in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(a.customerName).font(.subheadline.weight(.semibold))
                                Text("\(a.service.rawValue) • \(a.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(a.noShowRisk * 100))%").bold().foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section("Repair anomalies") {
                    ForEach(app.anomalies) { an in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(an.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                StatusBadge(text: an.risk.rawValue, color: an.risk.color)
                            }
                            Text(an.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Staff workload") {
                    ForEach(app.staff) { s in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(s.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(s.assignedJobs) active • \(s.completedJobs) done").font(.caption)
                            }
                            Text(s.role).font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: s.load).tint(s.load > 0.8 ? .red : (s.load > 0.5 ? .orange : .green))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }
}

#Preview { InsightsView().environment(AppState(role: .garageOwner)) }
