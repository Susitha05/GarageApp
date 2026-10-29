import SwiftUI

/// Add a part, or edit / delete an existing one when `editing` is passed.
struct InventoryEditView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let editing: InventoryItem?
    @State private var name: String
    @State private var sku: String
    @State private var stock: String
    @State private var minimum: String
    @State private var price: String
    @State private var confirmDelete = false

    init(editing: InventoryItem? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _sku = State(initialValue: editing?.sku ?? "")
        _stock = State(initialValue: editing.map { String($0.stock) } ?? "")
        _minimum = State(initialValue: editing.map { String($0.minThreshold) } ?? "")
        _price = State(initialValue: editing.map { String(Int($0.unitPrice)) } ?? "")
    }

    private var duplicateSKU: Bool {
        let value = sku.trimmingCharacters(in: .whitespaces).lowercased()
        return app.inventory.contains { $0.sku.lowercased() == value && $0.id != editing?.id }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !sku.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(stock) ?? -1) >= 0
            && (Int(minimum) ?? -1) >= 0
            && (Double(price) ?? -1) >= 0
            && !duplicateSKU
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                    TextField("SKU", text: $sku).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    if duplicateSKU {
                        Label("Another item already uses this SKU.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("Stock") {
                    TextField("Quantity in stock", text: $stock).keyboardType(.numberPad)
                    TextField("Minimum level (low-stock alert)", text: $minimum).keyboardType(.numberPad)
                }
                Section("Price") {
                    HStack { Text("Rs."); TextField("Unit price", text: $price).keyboardType(.decimalPad) }
                }
                if editing != nil {
                    Section {
                        Button("Remove item", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!isValid) }
            }
            .confirmationDialog("Remove this item?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let editing { app.removeInventoryItem(editing.id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanSKU = sku.trimmingCharacters(in: .whitespaces).uppercased()
        if var item = editing {
            item.name = cleanName
            item.sku = cleanSKU
            item.stock = Int(stock) ?? item.stock
            item.minThreshold = Int(minimum) ?? item.minThreshold
            item.unitPrice = Double(price) ?? item.unitPrice
            app.updateInventoryItem(item)
        } else {
            app.addInventoryItem(InventoryItem(name: cleanName, sku: cleanSKU, stock: Int(stock) ?? 0,
                                               minThreshold: Int(minimum) ?? 0, usedThisMonth: 0,
                                               forecastNextMonth: 0, unitPrice: Double(price) ?? 0))
        }
        dismiss()
    }
}

#Preview("Add") { InventoryEditView().environment(AppState(role: .garageOwner)) }
#Preview("Edit") { InventoryEditView(editing: MockData.inventory[0]).environment(AppState(role: .garageOwner)) }
