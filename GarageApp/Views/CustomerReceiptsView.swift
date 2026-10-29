import SwiftUI

/// Receipts issued by the garage, synced from Firestore.
struct CustomerReceiptsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        List(app.receipts.sorted { $0.date > $1.date }) { receipt in
            NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(receipt.garage).font(.headline)
                        Spacer()
                        Text(rs(receipt.total)).font(.headline)
                    }
                    Text("\(receipt.vehicleTitle) • \(receipt.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(receipt.number).font(.caption2).foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Receipts")
        .overlay {
            if app.receipts.isEmpty {
                ContentUnavailableView("No receipts yet", systemImage: "doc.text",
                                       description: Text("Your receipts appear here after a service is completed."))
            }
        }
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var pdf: PDFFile?

    var body: some View {
        List {
            Section {
                LabeledContent("Receipt", value: receipt.number)
                LabeledContent("Date", value: receipt.date.formatted(date: .long, time: .omitted))
                LabeledContent("Garage", value: receipt.garage)
                LabeledContent("Vehicle", value: receipt.vehicleTitle)
                LabeledContent("Mechanic", value: receipt.mechanic)
            }
            Section("Items") {
                ForEach(receipt.lines) { line in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(line.title)
                            Text("\(line.quantity) × \(rs(line.unitPrice))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rs(line.amount))
                    }
                }
                HStack { Text("Total").font(.headline); Spacer(); Text(rs(receipt.total)).font(.headline) }
            }
            if !receipt.notes.isEmpty {
                Section("Notes") { Text(receipt.notes) }
            }
            if let pdf {
                Section {
                    ShareLink(item: pdf.url) { Label("Share / save PDF", systemImage: "square.and.arrow.up") }
                }
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .task { pdf = ReceiptPDF.make(receipt) }
    }
}

#Preview {
    let state = AppState(role: .customer)
    state.receipts = [Receipt(
        appointmentID: UUID(), number: "R-20261028-001", customerName: "Sasanka", customerEmail: "s@example.com",
        vehicleTitle: "2016 Toyota Axio", garage: "AutoCare Garage", mechanic: "Ruwan Kumara",
        lines: [ReceiptLine(title: "Oil Change – service charge", quantity: 1, unitPrice: 3_500),
                ReceiptLine(title: "Oil Filter", quantity: 1, unitPrice: 1_200)])]
    return NavigationStack { CustomerReceiptsView() }.environment(state)
}
