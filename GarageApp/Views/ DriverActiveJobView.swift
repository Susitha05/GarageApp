import SwiftUI
import MapKit

struct DriverActiveJobView: View {
    @Environment(AppState.self) private var app
    @State private var location = LocationManager()
    @State private var route: MKRoute?

    private var job: TowRequest? { app.towRequests.first { $0.id == app.activeJobID } }

    var body: some View {
        NavigationStack {
            Group {
                if let job {
                    ZStack(alignment: .bottom) {
                        Map(initialPosition: .automatic) {
                            UserAnnotation()
                            Marker(job.customerName, systemImage: "car.fill", coordinate: job.coordinate).tint(.red)
                            if let route { MapPolyline(route.polyline).stroke(.blue, lineWidth: 5) }
                        }
                        .mapControls { MapUserLocationButton(); MapCompass() }

                        Card {
                            HStack {
                                Text(job.customerName).font(.headline)
                                Spacer()
                                StatusBadge(text: job.status.rawValue, color: job.status.color)
                            }
                            Label(job.address, systemImage: "mappin.and.ellipse").font(.subheadline)
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
                                    Button { app.advanceActiveJob() } label: {
                                        Text("Mark \(next.rawValue)").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                        .padding()
                    }
                    .task(id: job.id) {
                        location.start()
                        route = await RoutingService.route(from: location.coordinate, to: job.coordinate)
                    }
                    .onChange(of: location.isLive) { _, live in
                        guard live else { return }
                        Task { route = await RoutingService.route(from: location.coordinate, to: job.coordinate) }
                    }
                } else {
                    ContentUnavailableView("No active job", systemImage: "truck.box",
                                           description: Text("Accept a job from the Jobs tab to start navigation."))
                }
            }
            .navigationTitle("Active Job")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("With active job") {
    let state = AppState(role: .towDriver)
    state.acceptJob(state.towRequests[0].id)
    return DriverActiveJobView().environment(state)
}

#Preview("No active job") { DriverActiveJobView().environment(AppState(role: .towDriver)) }
