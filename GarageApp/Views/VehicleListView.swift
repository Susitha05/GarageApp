import SwiftUI

private enum VehicleSheet: Identifiable {
    case add
    case edit(Vehicle)
    var id: String {
        switch self {
        case .add: "add"
        case .edit(let v): v.id.uuidString
        }
    }
}

struct VehicleListView: View {
    @Environment(AppState.self) private var app
    @State private var sheet: VehicleSheet?
    @State private var pendingDelete: Vehicle?

    var body: some View {
        NavigationStack {
            List {
                ForEach(app.vehicles) { vehicle in
                    NavigationLink(destination: VehicleDetailView(vehicleID: vehicle.id)) {
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { pendingDelete = vehicle } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { sheet = .edit(vehicle) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("My Vehicles")
            .toolbar {
                Button { sheet = .add } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add vehicle")
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .add: AddVehicleView()
                case .edit(let vehicle): AddVehicleView(editing: vehicle)
                }
            }
            .confirmationDialog("Delete this vehicle?",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let v = pendingDelete { app.removeVehicle(v.id) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Its service history will be removed too.")
            }
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
