import SwiftUI
import MessageUI

/// Build a receipt for a finished job, deduct the parts from stock, then email / share it as a PDF.
struct ReceiptBuilderView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let appointmentID: UUID

    @State private var serviceCharge = ""
    @State private var extraTitle = ""
    @State private var extraAmount = ""
    @State private var quantities: [UUID: Int] = [:]
    @State private var email = ""
    @State private var notes = ""
    @State private var didLoad = false

    @State private var pdf: PDFFile?
    @State private var showMail = false
    @State private var mailUnavailable = false
    @State private var isQueuing = false
    @State private var statusText: String?

    private var appointment: Appointment? { app.appointments.first { $0.id == appointmentID } }

    var body: some View {
        NavigationStack {
            Group {
                if let receipt = app.receipt(for: appointmentID) {
                    issuedView(receipt)
                } else if let appointment {
                    formView(appointment)
                } else {
                    ContentUnavailableView("Appointment not found", systemImage: "doc")
                }
            }
            .navigationTitle(app.receipt(for: appointmentID) == nil ? "New Receipt" : "Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    // MARK: Step 1 – build the receipt
    private func formView(_ a: Appointment) -> some View {
        let partsTotal = app.inventory.reduce(0.0) { $0 + Double(quantities[$1.id, default: 0]) * $1.unitPrice }
        let total = (Double(serviceCharge) ?? 0) + partsTotal + (Double(extraAmount) ?? 0)

        return Form {
            Section("Customer") {
                LabeledContent("Name", value: a.customerName)
                LabeledContent("Vehicle", value: a.vehicleTitle)
                LabeledContent("Mechanic", value: a.assignedStaff ?? "Unassigned")
                TextField("Customer email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("Service charge") {
                HStack { Text("Rs."); TextField("Amount", text: $serviceCharge).keyboardType(.decimalPad) }
            }
            Section("Parts used (deducted from stock)") {
                if app.inventory.isEmpty { Text("No inventory items.").foregroundStyle(.secondary) }
                ForEach(app.inventory) { item in
                    Stepper(value: quantity(item), in: 0...max(item.stock, 0)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.name)  × \(quantities[item.id, default: 0])")
                            Text("\(rs(item.unitPrice)) • \(item.stock) in stock")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Other charges (optional)") {
                TextField("Description", text: $extraTitle)
                HStack { Text("Rs."); TextField("Amount", text: $extraAmount).keyboardType(.decimalPad) }
            }
            Section("Notes") {
                TextField("Notes shown on the receipt", text: $notes, axis: .vertical).lineLimit(2...4)
            }
            Section {
                HStack { Text("Total").font(.headline); Spacer(); Text(rs(total)).font(.headline) }
                Button { issue(a) } label: { Text("Issue receipt").frame(maxWidth: .infinity) }
                    .disabled(total <= 0)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            serviceCharge = String(Int(a.service.basePrice))
            email = a.customerEmail
        }
    }

    private func quantity(_ item: InventoryItem) -> Binding<Int> {
        Binding(get: { quantities[item.id, default: 0] }, set: { quantities[item.id] = $0 })
    }

    private func issue(_ a: Appointment) {
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        var lines = [ReceiptLine(title: "\(a.service.rawValue) – service charge", quantity: 1,
                                 unitPrice: Double(serviceCharge) ?? 0)]
        for item in app.inventory {
            if let q = quantities[item.id], q > 0 {
                lines.append(ReceiptLine(title: item.name, quantity: q, unitPrice: item.unitPrice))
            }
        }
        if let extra = Double(extraAmount), extra > 0 {
            let title = extraTitle.trimmingCharacters(in: .whitespaces)
            lines.append(ReceiptLine(title: title.isEmpty ? "Other charges" : title, quantity: 1, unitPrice: extra))
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let number = "R-\(formatter.string(from: .now))-\(String(format: "%03d", app.receipts.count + 1))"

        var updated = a
        updated.customerEmail = cleanEmail
        app.updateAppointment(updated)

        let receipt = Receipt(appointmentID: a.id, number: number, customerName: a.customerName,
                              customerEmail: cleanEmail, vehicleTitle: a.vehicleTitle, garage: a.garage,
                              mechanic: a.assignedStaff ?? "—", lines: lines,
                              notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                              customerUid: a.customerUid)
        let parts = quantities.filter { $0.value > 0 }.map { (id: $0.key, quantity: $0.value) }
        app.issueReceipt(receipt, parts: parts)
    }

    // MARK: Step 2 – send it
    private func issuedView(_ receipt: Receipt) -> some View {
        let mail = EmailTemplates.receipt(receipt)
        let fileName = "Receipt-\(receipt.number).pdf"

        return List {
            Section {
                LabeledContent("Receipt", value: receipt.number)
                LabeledContent("Customer", value: receipt.customerName)
                LabeledContent("Email", value: receipt.customerEmail.isEmpty ? "—" : receipt.customerEmail)
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
            Section {
                if let sent = receipt.sentAt {
                    Label("Sent \(sent.formatted(date: .abbreviated, time: .shortened))",
                          systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                }
                Button {
                    if MailView.canSend { showMail = true } else { mailUnavailable = true }
                } label: {
                    Label("Email receipt (Mail app)", systemImage: "envelope")
                }
                .disabled(pdf == nil)

                if let pdf {
                    ShareLink(item: pdf.url, subject: Text(mail.subject), message: Text(mail.body)) {
                        Label("Share PDF…", systemImage: "square.and.arrow.up")
                    }
                }
                if EmailService.isAvailable, !receipt.customerEmail.isEmpty {
                    Button {
                        Task { await sendAutomatically(receipt, mail, fileName) }
                    } label: {
                        Label(isQueuing ? "Sending…" : "Send automatically (server email)", systemImage: "paperplane")
                    }
                    .disabled(isQueuing || pdf == nil)
                }
                if receipt.sentAt == nil {
                    Button("Mark as sent") { app.markReceiptSent(receipt.id) }
                }
            } header: {
                Text("Send to customer")
            } footer: {
                Text(statusText ?? "The receipt is attached to the email as a PDF.")
            }
        }
        .task(id: receipt.id) { pdf = await ReceiptPDF.make(receipt) }
        .sheet(isPresented: $showMail) {
            MailView(to: receipt.customerEmail, subject: mail.subject, body: mail.body,
                     attachment: pdf.map { (name: fileName, data: $0.data) }) { result in
                if result == .sent { app.markReceiptSent(receipt.id) }
            }
        }
        .alert("Mail isn't set up", isPresented: $mailUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add a Mail account in Settings, or use Share PDF to send it with Messages, WhatsApp or another app.")
        }
    }

    private func sendAutomatically(_ receipt: Receipt, _ mail: EmailContent, _ fileName: String) async {
        guard let pdf else { return }
        isQueuing = true
        defer { isQueuing = false }
        let ok = await EmailService.queue(to: receipt.customerEmail, subject: mail.subject, text: mail.body,
                                          attachment: (name: fileName, data: pdf.data))
        if ok {
            app.markReceiptSent(receipt.id)
            statusText = "Queued for delivery to \(receipt.customerEmail)."
        } else {
            statusText = "Couldn't queue the email. Check the Firestore rules and the email extension (see README)."
        }
    }
}

#Preview {
    let state = AppState(role: .garageOwner)
    return ReceiptBuilderView(appointmentID: state.appointments.first { $0.status == .completed }!.id)
        .environment(state)
}
