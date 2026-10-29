import SwiftUI

/// The printed layout of a receipt (also rendered to PDF).
struct ReceiptDocumentView: View {
    let receipt: Receipt

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(receipt.garage).font(.system(size: 26, weight: .bold))
                    Text("Service receipt").foregroundStyle(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("No. \(receipt.number)").font(.headline)
                    Text(receipt.date.formatted(date: .long, time: .omitted)).foregroundStyle(.gray)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                detail("Customer", receipt.customerName)
                detail("Vehicle", receipt.vehicleTitle)
                detail("Mechanic", receipt.mechanic)
            }
            Divider()
            HStack {
                Text("Description").frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty").frame(width: 40, alignment: .trailing)
                Text("Unit").frame(width: 90, alignment: .trailing)
                Text("Amount").frame(width: 100, alignment: .trailing)
            }
            .font(.footnote.weight(.semibold)).foregroundStyle(.gray)
            ForEach(receipt.lines) { line in
                HStack(alignment: .top) {
                    Text(line.title).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(line.quantity)").frame(width: 40, alignment: .trailing)
                    Text(rs(line.unitPrice)).frame(width: 90, alignment: .trailing)
                    Text(rs(line.amount)).frame(width: 100, alignment: .trailing)
                }
                .font(.system(size: 13))
            }
            Divider()
            HStack {
                Spacer()
                Text("Total").font(.headline)
                Text(rs(receipt.total)).font(.system(size: 22, weight: .bold))
            }
            if !receipt.notes.isEmpty {
                Text("Notes: \(receipt.notes)").font(.footnote).foregroundStyle(.gray)
            }
            Text("Thank you for your business!").font(.footnote).foregroundStyle(.gray).padding(.top, 8)
        }
        .padding(32)
        .frame(width: 595, alignment: .topLeading)   // A4 width in points
        .foregroundStyle(Color.black)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.gray).frame(width: 90, alignment: .leading)
            Text(value)
        }
        .font(.system(size: 13))
    }
}

struct PDFFile {
    let url: URL
    let data: Data
}

enum ReceiptPDF {
    @MainActor
    static func make(_ receipt: Receipt) -> PDFFile? {
        let renderer = ImageRenderer(content: ReceiptDocumentView(receipt: receipt))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt-\(receipt.number).pdf")
        var rendered = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            rendered = true
        }
        guard rendered, let data = try? Data(contentsOf: url) else { return nil }
        return PDFFile(url: url, data: data)
    }
}

#Preview {
    ReceiptDocumentView(receipt: Receipt(
        appointmentID: UUID(), number: "R-20261028-001", customerName: "Nimal Perera",
        customerEmail: "nimal@example.com", vehicleTitle: "2016 Toyota Axio", garage: "AutoCare Garage",
        mechanic: "Ruwan Kumara",
        lines: [ReceiptLine(title: "Oil Change – service charge", quantity: 1, unitPrice: 3_500),
                ReceiptLine(title: "Engine Oil 5W-30 (4L)", quantity: 1, unitPrice: 4_500),
                ReceiptLine(title: "Oil Filter", quantity: 1, unitPrice: 1_200)],
        notes: "Next service due in 5,000 km."))
}
