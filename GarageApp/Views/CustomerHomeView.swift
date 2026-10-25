import SwiftUI

struct CustomerHomeView: View {
    @Environment(AppState.self) private var app
    private let predictor = MaintenancePredictor()

    private var topPredictions: [(Vehicle, PredictedMaintenance)] {
        app.vehicles.compactMap { v in
            predictor.predict(for: v, records: app.records).first.map { (v, $0) }
        }
    }
    private var totalSpent: Double { app.expenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hello, \(app.userName.components(separatedBy: " ").first ?? "there") 👋")
                        .font(.title2.bold())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Vehicles", value: "\(app.vehicles.count)", icon: "car.fill")
                        StatTile(title: "Total spent", value: rs(totalSpent), icon: "creditcard.fill", tint: .green)
                    }

                    SectionTitle("Predicted maintenance")
                    ForEach(topPredictions, id: \.1.id) { vehicle, p in
                        Card {
                            HStack {
                                Text(vehicle.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                StatusBadge(text: p.risk.rawValue, color: p.risk.color)
                            }
                            Text(p.dueInKm < 0 ? "\(p.part) overdue by \(-p.dueInKm) km"
                                                : "\(p.part) due in ~\(p.dueInKm) km")
                            Text("Confidence \(Int(p.confidence * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    SectionTitle("Quick actions")
                    HStack(spacing: 12) {
                        NavigationLink(destination: ExpensesView()) {
                            quickAction("Expenses", "chart.bar.fill")
                        }
                        NavigationLink(destination: NotificationsView()) {
                            quickAction("Alerts", "bell.fill")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .onAppear { app.publishWidgetSnapshot() }
        }
    }

    private func quickAction(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.primary)
    }
}

#Preview { CustomerHomeView().environment(AppState(role: .customer)) }
