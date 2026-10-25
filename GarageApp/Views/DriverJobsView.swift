import SwiftUI

struct DriverJobsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            List(app.towRequests) { job in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(job.customerName).font(.headline)
                        Spacer()
                        StatusBadge(text: job.status.rawValue, color: job.status.color)
                    }
                    Text(job.vehicleTitle).font(.subheadline)
                    Label(job.address, systemImage: "mappin.and.ellipse").font(.caption)
                    Text(String(format: "%.1f km away", job.distanceKm)).font(.caption).foregroundStyle(.secondary)
                    if job.status == .requested {
                        Button("Accept job") { app.acceptJob(job.id) }.buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Tow Jobs")
        }
    }
}

#Preview { DriverJobsView().environment(AppState(role: .towDriver)) }
