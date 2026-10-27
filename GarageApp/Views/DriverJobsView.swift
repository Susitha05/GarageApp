import SwiftUI

struct DriverJobsView: View {
    @Environment(AuthService.self) private var auth
    private let tow = TowService.shared
    private let location = LocationManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section { statusRow }

                if !tow.activeDriverJobs.isEmpty {
                    Section("My jobs") {
                        ForEach(tow.activeDriverJobs) { job in
                            Button { tow.select(job.id) } label: {
                                HStack {
                                    row(job)
                                    if tow.activeDriverJob?.id == job.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    if tow.openRequests.isEmpty {
                        Text("No open requests right now.").foregroundStyle(.secondary)
                    }
                    ForEach(tow.openRequests) { row($0) }
                } header: {
                    Text("Available requests")
                } footer: {
                    Text("You can accept several jobs. Switch between them on the Active tab.")
                }
            }
            .navigationTitle("Tow Jobs")
            .refreshable { await reload() }
            .alert("Tow jobs", isPresented: Binding(get: { tow.errorMessage != nil },
                                                    set: { if !$0 { tow.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(tow.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if let error = tow.driverListenError {
            VStack(alignment: .leading, spacing: 4) {
                Label("Can't load requests", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button("Retry now") { Task { await reload() } }.font(.caption.bold())
            }
        } else {
            Label("Live • \(tow.openRequests.count) open request\(tow.openRequests.count == 1 ? "" : "s")",
                  systemImage: "dot.radiowaves.left.and.right")
                .foregroundStyle(.green).font(.subheadline)
        }
    }

    @ViewBuilder
    private func row(_ job: TowRequest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.customerName).font(.headline)
                Spacer()
                StatusBadge(text: job.status.rawValue, color: job.status.color)
            }
            Text(job.vehicleTitle).font(.subheadline)
            Label(job.address, systemImage: "mappin.and.ellipse").font(.caption)
            if let km = location.distanceKm(to: job.coordinate) {
                Text(String(format: "%.1f km away", km)).font(.caption).foregroundStyle(.secondary)
            }
            if job.status == .requested {
                Button("Accept job") {
                    guard let user = auth.user else { return }
                    Task { await tow.accept(job, driver: user, coordinate: location.coordinate) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private func reload() async {
        if let uid = auth.user?.uid { tow.listenAsDriver(uid: uid) }
        try? await Task.sleep(nanoseconds: 600_000_000)
    }
}

#Preview {
    DriverJobsView()
        .environment(AuthService.preview(user: AppUser(uid: "d1", name: "Saman", email: "saman@example.com", role: .towDriver)))
}
