import SwiftUI

private enum InventorySheet: Identifiable {
    case add
    case edit(InventoryItem)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let item): item.id.uuidString
        }
    }
}

struct InventoryView: View {
    @Environment(AppState.self) private var app
    @State private var sheet: InventorySheet?
    @State private var pendingDelete: InventoryItem?
    @State private var search = ""

    private var items: [InventoryItem] {
        guard !search.isEmpty else { return app.inventory }
        return app.inventory.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.sku.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.name).font(.headline)
                        Spacer()
                        if item.isLow { StatusBadge(text: "Low stock", color: .red) }
                    }
                    Text("\(item.sku) • \(rs(item.unitPrice)) each").font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(item.stock), total: Double(max(item.minThreshold * 3, item.stock, 1)))
                        .tint(item.isLow ? .red : .blue)
                    HStack {
                        Text("Min \(item.minThreshold) • Forecast \(item.forecastNextMonth)/mo")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 14) {
                            Button { app.adjustStock(item.id, by: -1) } label: { Image(systemName: "minus.circle.fill") }
                                .accessibilityLabel("Decrease stock of \(item.name)")
                            Text("\(item.stock)").font(.headline.monospacedDigit()).frame(minWidth: 28)
                            Button { app.adjustStock(item.id, by: 1) } label: { Image(systemName: "plus.circle.fill") }
                                .accessibilityLabel("Increase stock of \(item.name)")
                        }
                        .buttonStyle(.borderless)
                        .font(.title3)
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingDelete = item } label: { Label("Delete", systemImage: "trash") }
                    Button { sheet = .edit(item) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                }
            }
            .navigationTitle("Inventory")
            .searchable(text: $search, prompt: "Search name or SKU")
            .toolbar {
                Button { sheet = .add } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add item")
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .add: InventoryEditView()
                case .edit(let existing): InventoryEditView(editing: existing)
                }
            }
            .confirmationDialog("Remove this item?",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let item = pendingDelete { app.removeInventoryItem(item.id) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text(pendingDelete.map { "\($0.name) will be removed from your inventory." } ?? "")
            }
            .overlay {
                if app.inventory.isEmpty {
                    ContentUnavailableView {
                        Label("No items", systemImage: "shippingbox")
                    } description: {
                        Text("Tap + to add your first part.")
                    } actions: {
                        Button("Add sample parts") { app.seedSampleInventory() }
                    }
                }
            }
        }
    }
}

#Preview { InventoryView().environment(AppState(role: .garageOwner)) }
