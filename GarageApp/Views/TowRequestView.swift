import SwiftUI
import MapKit

struct TowRequestView: View {
    @State private var status: TowStatus?
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 7.2000, longitude: 79.8450),
                           span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)))

    private let me = CLLocationCoordinate2D(latitude: 7.2085, longitude: 79.8358)
    private var driver: CLLocationCoordinate2D {
        switch status {
        case .none, .requested: CLLocationCoordinate2D(latitude: 7.1850, longitude: 79.8600)
        case .accepted, .enRoute: CLLocationCoordinate2D(latitude: 7.1990, longitude: 79.8440)
        default: me
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $camera) {
                    Marker("You", systemImage: "person.fill", coordinate: me).tint(.blue)
                    if status != nil {
                        Marker("Tow driver", systemImage: "truck.box.fill", coordinate: driver).tint(.orange)
                    }
                }
                .ignoresSafeArea(edges: .top)

                Card {
                    if let status {
                        HStack {
                            Text("Tow request").font(.headline)
                            Spacer()
                            StatusBadge(text: status.rawValue, color: status.color)
                        }
                        Text(status == .completed ? "Your vehicle has been delivered." : "ETA about 8 minutes")
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
                        Text("We'll share your live location with the nearest tow driver.")
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
        }
    }
}

#Preview { TowRequestView().environment(AppState(role: .customer)) }
