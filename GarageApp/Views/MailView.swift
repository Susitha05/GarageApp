import SwiftUI
import MessageUI

/// Wraps the system Mail composer (needs a Mail account on the device; not available in the Simulator).
struct MailView: UIViewControllerRepresentable {
    var to: String
    var subject: String
    var body: String
    var attachment: (name: String, data: Data)? = nil
    var onFinish: (MFMailComposeResult) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    static var canSend: Bool { MFMailComposeViewController.canSendMail() }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if !to.isEmpty { vc.setToRecipients([to]) }
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let attachment {
            vc.addAttachmentData(attachment.data, mimeType: "application/pdf", fileName: attachment.name)
        }
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView
        init(_ parent: MailView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.onFinish(result)
            parent.dismiss()
        }
    }
}

/// Opens Mail pre-filled with the booking status message, or offers Share when Mail isn't set up.
struct EmailCustomerSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let appointmentID: UUID

    var body: some View {
        if let a = app.appointments.first(where: { $0.id == appointmentID }) {
            let mail = EmailTemplates.bookingUpdate(a)
            if MailView.canSend {
                MailView(to: a.customerEmail, subject: mail.subject, body: mail.body)
            } else {
                NavigationStack {
                    ContentUnavailableView {
                        Label("Mail isn't set up", systemImage: "envelope.badge")
                    } description: {
                        Text("Add a Mail account in Settings, or share the message with another app.")
                    } actions: {
                        ShareLink(item: mail.body, subject: Text(mail.subject)) {
                            Label("Share message", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                }
            }
        }
    }
}
