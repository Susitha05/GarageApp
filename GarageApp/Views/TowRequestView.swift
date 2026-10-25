import SwiftUI
import MapKit
import UIKit

struct TowRequestView: View {
    @Environment(\.openURL) private var openURL
    @State private var location = LocationManager()
    @State private var status: TowStatus?
    @State private var route: MKRoute?
    @State private var hasCentered = false
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: LocationManager.fallback,
                           span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)))

    private var me: CLLocationCoordinate2D { location.coordinate }

    /// Simulated driver position until Firebase streams the real one.
    private var driver: CLLocationCoordinate2D {
        let start = CLLocationCoordinate2D(latitude: me.latitude - 0.018, longitude: me.longitude + 0.022)
        let f: Double
        switch status {
        case .none, .requested: f = 1
        case .accepted: f = 0.75
        case .enRoute: f = 0.35
        default: f = 0
        }
        return CLLocationCoordinate2D(latitude: me.latitude + (start.latitude - me.latitude) * f,
                                      longitude: me.longitude + (start.longitude - me.longitude) * f)
    }

    private var etaMinutes: Int { route.map { max(1, Int($0.expectedTravelTime / 60)) } ?? 8 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $camera) {
                    Marker("You", systemImage: "person.fill", coordinate: me).tint(.blue)
                    if status != nil {
                        Marker("Tow driver", systemImage: "truck.box.fill", coordinate: driver).tint(.orange)
                        if let route { MapPolyline(route.polyline).stroke(.blue, lineWidth: 5) }
                    }
                }
                .mapControls { MapUserLocationButton(); MapCompass() }
                .ignoresSafeArea(edges: .top)

                Card {
                    locationRow
                    Divider()
                    if let status {
                        HStack {
                            Text("Tow request").font(.headline)
                            Spacer()
                            StatusBadge(text: status.rawValue, color: status.color)
                        }
                        Text(status == .completed ? "Your vehicle has been delivered."
                                                  : "Driver ETA about \(etaMinutes) min")
                            .foregroundStyle(.secondary)
                        HStack {
                            if let next = status.next {
                                Button("Simulate: \(next.rawValue)") { self.status = next }
                                    .buttonStyle(.bordered)
                            }
                            Button("Cancel", role: .destructive) { self.status = nil }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        Text("Broken down?").font(.headline)
                        Text("Your live location is shared with the nearest tow driver.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { status = .requested } label: {
                            Label("Request tow", systemImage: "exclamationmark.triangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Towing")
            .navigationBarTitleDisplayMode(.inline)
            .task { location.start() }
            .onDisappear { location.stop() }
            .onChange(of: location.location) { _, new in
                guard new != nil, !hasCentered else { return }
                hasCentered = true
                camera = .region(MKCoordinateRegion(center: me, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
            .onChange(of: status) { _, _ in Task { await refreshRoute() } }
        }
    }

    private var locationRow: some View {
        HStack {
            Label(location.statusText, systemImage: location.isLive ? "location.fill" : "location.slash")
                .font(.caption).lineLimit(1)
            Spacer()
            if location.isDenied {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.caption.bold())
            } else {
                Text(String(format: "%.4f, %.4f", me.latitude, me.longitude))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func refreshRoute() async {
        guard status != nil, status != .arrived, status != .towing, status != .completed else { route = nil; return }
        route = await RoutingService.route(from: driver, to: me)
    }
}

#Preview { TowRequestView().environment(AppState(role: .customer)) }
