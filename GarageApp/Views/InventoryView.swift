import SwiftUI

struct InventoryView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            List(app.inventory) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name).font(.headline)
                        Spacer()
                        if item.isLow { StatusBadge(text: "Low stock", color: .red) }
                    }
                    Text(item.sku).font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(item.stock), total: Double(max(item.minThreshold * 3, item.stock)))
                        .tint(item.isLow ? .red : .blue)
                    HStack {
                        Text("Stock \(item.stock) (min \(item.minThreshold))")
                        Spacer()
                        Text("Forecast next month: \(item.forecastNextMonth)")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Inventory")
        }
    }
}

#Preview { InventoryView().environment(AppState(role: .garageOwner)) }
