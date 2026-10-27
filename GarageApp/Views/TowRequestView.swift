import SwiftUI
import MapKit
import UIKit

struct TowRequestView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    private let location = LocationManager.shared
    private let tow = TowService.shared

    @State private var vehicleID: UUID?
    @State private var route: MKRoute?
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var hasCentered = false
    @State private var isSending = false

    private var request: TowRequest? { tow.customerRequest }
    private var etaMinutes: Int? { route.map { max(1, Int($0.expectedTravelTime / 60)) } }

    private var routeKey: String {
        guard let r = request, r.status.isActive, let d = r.driverCoordinate else { return "none" }
        return String(format: "%.3f,%.3f|%.3f,%.3f", d.latitude, d.longitude, r.latitude, r.longitude)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $camera) {
                    UserAnnotation()
                    if location.isSampleLocation {
                        Marker("You", systemImage: "person.fill", coordinate: location.coordinate).tint(.blue)
                    }
                    if let r = request {
                        Marker("Pickup", systemImage: "car.fill", coordinate: r.coordinate).tint(.red)
                        if r.status.isActive, let d = r.driverCoordinate {
                            Marker(r.driverName ?? "Tow driver", systemImage: "truck.box.fill", coordinate: d).tint(.orange)
                            if let route { MapPolyline(route.polyline).stroke(.blue, lineWidth: 5) }
                        }
                    }
                }
                .mapControls { MapUserLocationButton(); MapCompass() }
                .ignoresSafeArea(edges: .top)

                Card {
                    locationRow
                    Divider()
                    if let r = request { activeCard(r) } else { newRequestCard }
                }
                .padding()
            }
            .navigationTitle("Towing")
            .navigationBarTitleDisplayMode(.inline)
            .task { location.start() }
            .onAppear { if vehicleID == nil { vehicleID = app.vehicles.first?.id } }
            .task(id: routeKey) { await refreshRoute() }
            .onChange(of: location.location) { _, new in
                guard let new else { return }
                if !hasCentered {
                    hasCentered = true
                    camera = .region(MKCoordinateRegion(center: new.coordinate,
                                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                }
                if let r = request, r.status.isActive {
                    Task { await tow.pushCustomerLocation(r, coordinate: new.coordinate) }
                }
            }
            .alert("Tow request", isPresented: Binding(get: { tow.errorMessage != nil },
                                                       set: { if !$0 { tow.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(tow.errorMessage ?? "")
            }
        }
    }

    // MARK: Pieces
    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(location.statusText, systemImage: location.isLive ? "location.fill" : "location.slash")
                .font(.caption)
            if location.isDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.caption.bold())
            } else if location.authorization == .notDetermined {
                Button("Allow location") { location.start() }.font(.caption.bold())
            } else if !location.isLive {
                Button("Use sample location (testing)") { location.useSampleLocation() }.font(.caption)
            }
        }
    }

    private var newRequestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Broken down?").font(.headline)
            Text("Your live location is shared with nearby tow drivers once you send a request.")
                .font(.subheadline).foregroundStyle(.secondary)
            if !app.vehicles.isEmpty {
                Picker("Vehicle", selection: $vehicleID) {
                    ForEach(app.vehicles) { Text($0.title).tag(Optional($0.id)) }
                }
                .pickerStyle(.menu)
            }
            Button { Task { await send() } } label: {
                Group {
                    if isSending { ProgressView().tint(.white) }
                    else { Label("Request tow", systemImage: "exclamationmark.triangle.fill") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.red)
            .disabled(!location.isLive || isSending)
        }
    }

    @ViewBuilder
    private func activeCard(_ r: TowRequest) -> some View {
        HStack {
            Text("Tow request").font(.headline)
            Spacer()
            StatusBadge(text: r.status.rawValue, color: r.status.color)
        }
        Text(r.vehicleTitle).font(.subheadline)
        Text(statusMessage(r)).foregroundStyle(.secondary)

        if r.status == .completed {
            Button("Done") { tow.dismiss(r.id) }.buttonStyle(.borderedProminent)
        } else if r.status == .requested || r.status == .accepted || r.status == .enRoute {
            Button("Cancel request", role: .destructive) { Task { await tow.cancel(r) } }
                .buttonStyle(.bordered)
        }
    }

    private func statusMessage(_ r: TowRequest) -> String {
        let driver = r.driverName ?? "Your driver"
        let eta = etaMinutes.map { " • ETA \($0) min" } ?? ""
        switch r.status {
        case .requested: return "Looking for a nearby driver…"
        case .accepted: return "\(driver) accepted your request\(eta)"
        case .enRoute: return "\(driver) is on the way\(eta)"
        case .arrived: return "\(driver) has arrived"
        case .towing: return "Your vehicle is being towed"
        case .completed: return "Delivered. Thanks for using Smart Garage."
        case .cancelled: return "Request cancelled"
        }
    }

    private func send() async {
        guard let user = auth.user else { tow.errorMessage = "Please sign in first."; return }
        isSending = true
        defer { isSending = false }
        let title = app.vehicles.first { $0.id == vehicleID }?.title ?? "Vehicle"
        await tow.requestTow(user: user, vehicleTitle: title, coordinate: location.coordinate,
                             address: location.address ?? "Shared GPS location")
    }

    private func refreshRoute() async {
        guard let r = request, r.status.isActive, let d = r.driverCoordinate else { route = nil; return }
        route = await RoutingService.route(from: d, to: r.coordinate)
    }
}

#Preview("New request") {
    TowRequestView()
        .environment(AppState(role: .customer))
        .environment(AuthService.preview(user: AppUser(uid: "c1", name: "Sasanka", email: "s@example.com", role: .customer)))
}

#Preview("Driver on the way") {
    LocationManager.shared.useSampleLocation()
    TowService.shared.customerRequests = [
        TowRequest(customerUid: "c1", customerName: "Sasanka", vehicleTitle: "2016 Toyota Axio",
                   address: "Colombo Rd, Negombo", latitude: 7.2085, longitude: 79.8358, status: .enRoute,
                   driverUid: "d1", driverName: "Saman", driverLatitude: 7.1950, driverLongitude: 79.8500)
    ]
    return TowRequestView()
        .environment(AppState(role: .customer))
        .environment(AuthService.preview(user: AppUser(uid: "c1", name: "Sasanka", email: "s@example.com", role: .customer)))
}
