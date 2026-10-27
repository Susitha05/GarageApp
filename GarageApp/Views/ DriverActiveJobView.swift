import SwiftUI
import MapKit

struct DriverActiveJobView: View {
    private let tow = TowService.shared
    private let location = LocationManager.shared
    @State private var route: MKRoute?

    private var job: TowRequest? { tow.activeDriverJob }

    private var routeKey: String {
        guard let j = job, j.status == .accepted || j.status == .enRoute else { return "none" }
        return String(format: "%@|%.3f,%.3f|%.3f,%.3f", j.id, location.coordinate.latitude,
                      location.coordinate.longitude, j.latitude, j.longitude)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let job { content(job) } else {
                    ContentUnavailableView("No active job", systemImage: "truck.box",
                                           description: Text("Accept a job from the Jobs tab to start navigation."))
                }
            }
            .navigationTitle("Active Job")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: routeKey) {
                guard let j = job, j.status == .accepted || j.status == .enRoute else { route = nil; return }
                route = await RoutingService.route(from: location.coordinate, to: j.coordinate)
            }
            .onChange(of: location.location) { _, new in
                guard let new else { return }
                for j in tow.activeDriverJobs {
                    Task { await tow.pushDriverLocation(j, coordinate: new.coordinate) }
                }
            }
        }
    }

    private func content(_ job: TowRequest) -> some View {
        ZStack(alignment: .bottom) {
            Map(initialPosition: .automatic) {
                UserAnnotation()
                Marker(job.customerName, systemImage: "car.fill", coordinate: job.coordinate).tint(.red)
                if let route { MapPolyline(route.polyline).stroke(.blue, lineWidth: 5) }
            }
            .mapControls { MapUserLocationButton(); MapCompass() }

            Card {
                if tow.activeDriverJobs.count > 1 {
                    Picker("Job", selection: Binding(get: { job.id }, set: { tow.select($0) })) {
                        ForEach(tow.activeDriverJobs) { Text($0.customerName).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                }
                HStack {
                    Text(job.customerName).font(.headline)
                    Spacer()
                    StatusBadge(text: job.status.rawValue, color: job.status.color)
                }
                Text(job.vehicleTitle).font(.subheadline)
                Label(job.address, systemImage: "mappin.and.ellipse").font(.subheadline)
                if !location.isLive {
                    Label(location.statusText, systemImage: "location.slash").font(.caption).foregroundStyle(.orange)
                }
                if let route {
                    Label(String(format: "%.1f km • %d min", route.distance / 1000,
                                 max(1, Int(route.expectedTravelTime / 60))),
                          systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline).foregroundStyle(.blue)
                }
                HStack {
                    Button { RoutingService.openInMaps(job.coordinate, name: job.customerName) } label: {
                        Label("Navigate", systemImage: "location.north.fill")
                    }
                    .buttonStyle(.bordered)
                    if let next = job.status.next {
                        Button { Task { await tow.advance(job) } } label: {
                            Text("Mark \(next.rawValue)").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("With active job") {
    TowService.shared.driverJobs = [
        TowRequest(customerUid: "c1", customerName: "Nimal Perera", vehicleTitle: "2016 Toyota Axio",
                   address: "Colombo Rd, Negombo", latitude: 7.2085, longitude: 79.8358, status: .enRoute,
                   driverUid: "d1", driverName: "Saman")
    ]
    return DriverActiveJobView()
}

#Preview("No active job") {
    TowService.shared.driverJobs = []
    return DriverActiveJobView()
}
