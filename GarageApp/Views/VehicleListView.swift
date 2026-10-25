import SwiftUI

struct VehicleListView: View {
    @Environment(AppState.self) private var app
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(app.vehicles) { vehicle in
                    NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                        HStack(spacing: 14) {
                            Image(systemName: "car.fill").font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.title).font(.headline)
                                Text("\(vehicle.registration) • \(vehicle.mileage.formatted()) km")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { app.vehicles.remove(atOffsets: $0) }
            }
            .navigationTitle("My Vehicles")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add vehicle")
            }
            .sheet(isPresented: $showAdd) { AddVehicleView() }
            .overlay {
                if app.vehicles.isEmpty {
                    ContentUnavailableView("No vehicles", systemImage: "car",
                                           description: Text("Tap + to register your first vehicle."))
                }
            }
        }
    }
}

#Preview { VehicleListView().environment(AppState(role: .customer)) }
