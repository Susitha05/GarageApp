import WidgetKit
import SwiftUI

struct StatusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let entry = StatusEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .sample)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private func riskColor(_ risk: String) -> Color {
    switch risk {
    case "High": .red
    case "Medium": .orange
    default: .green
    }
}

private func dueText(_ km: Int) -> String {
    km < 0 ? "Overdue \(abs(km).formatted()) km" : "In ~\(km.formatted()) km"
}

struct GarageStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        let s = entry.snapshot
        Group {
            switch family {
            case .accessoryInline:
                Text("\(s.topPart): \(dueText(s.dueInKm))")

            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "wrench.fill")
                        Text(s.risk.prefix(1)).font(.headline)
                    }
                }

            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label(s.topPart, systemImage: "wrench.fill").font(.headline)
                    Text(dueText(s.dueInKm)).font(.caption)
                    if let t = s.nextAppointmentTitle { Text(t).font(.caption2).lineLimit(1) }
                }

            case .systemMedium:
                HStack(alignment: .top, spacing: 16) {
                    maintenanceBlock(s)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Next booking", systemImage: "calendar").font(.caption.bold()).foregroundStyle(.secondary)
                        if let t = s.nextAppointmentTitle, let d = s.nextAppointmentDate {
                            Text(t).font(.subheadline.weight(.semibold)).lineLimit(2)
                            Text(d, style: .date).font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("None scheduled").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let tow = s.towStatus {
                            Label("Tow: \(tow)", systemImage: "truck.box.fill").font(.caption).foregroundStyle(.blue)
                        }
                    }
                    Spacer(minLength: 0)
                }

            default:
                maintenanceBlock(s)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func maintenanceBlock(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(s.vehicleName, systemImage: "car.fill")
                .font(.caption.bold()).foregroundStyle(.secondary).lineLimit(1)
            Text(s.topPart).font(.headline)
            Text(dueText(s.dueInKm)).font(.subheadline).foregroundStyle(riskColor(s.risk))
            Spacer(minLength: 0)
            Text("\(s.risk) risk").font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(riskColor(s.risk).opacity(0.2), in: Capsule())
                .foregroundStyle(riskColor(s.risk))
        }
    }
}

struct GarageStatusWidget: Widget {
    let kind = "GarageStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            GarageStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Vehicle Status")
        .description("Next predicted maintenance and your upcoming booking.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

#Preview("Small", as: .systemSmall) {
    GarageStatusWidget()
} timeline: {
    StatusEntry(date: .now, snapshot: .sample)
}

#Preview("Medium", as: .systemMedium) {
    GarageStatusWidget()
} timeline: {
    StatusEntry(date: .now, snapshot: .sample)
}

#Preview("Lock screen", as: .accessoryRectangular) {
    GarageStatusWidget()
} timeline: {
    StatusEntry(date: .now, snapshot: .sample)
}
