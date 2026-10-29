import Foundation
import FirebaseCore
import FirebaseFirestore

typealias EmailContent = (subject: String, body: String)

/// Automatic emails: writes a document to the `mail` collection, which the Firebase
/// "Trigger Email from Firestore" extension turns into a real email (see README).
enum EmailService {
    static var isAvailable: Bool { FirebaseApp.app() != nil }

    /// Returns true when the request was queued (not when it was delivered).
    static func queue(to address: String, subject: String, text: String,
                      attachment: (name: String, data: Data)? = nil) async -> Bool {
        let recipient = address.trimmingCharacters(in: .whitespaces)
        guard isAvailable, AuthService.isValidEmail(recipient) else { return false }

        var message: [String: Any] = ["subject": subject, "text": text, "html": html(from: text)]
        if let attachment {
            message["attachments"] = [[
                "filename": attachment.name,
                "content": attachment.data.base64EncodedString(),
                "encoding": "base64"
            ]]
        }
        do {
            _ = try await Firestore.firestore().collection("mail").addDocument(data: [
                "to": [recipient],
                "message": message,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            return false
        }
    }

    private static func html(from text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}

enum EmailTemplates {
    static func bookingReceived(_ a: Appointment) -> EmailContent {
        ("Booking received – \(a.service.rawValue)",
         """
         Hi \(a.customerName),

         Thanks for booking with \(a.garage). We've received your request:

         Service: \(a.service.rawValue)
         Vehicle: \(a.vehicleTitle)
         When: \(a.date.formatted(date: .complete, time: .shortened))

         The garage will confirm your booking shortly and you'll receive another email.

         – \(a.garage)
         """)
    }

    static func bookingUpdate(_ a: Appointment) -> EmailContent {
        let mechanic = a.assignedStaff.map { "\nMechanic: \($0)" } ?? ""
        let headline: String
        switch a.status {
        case .accepted: headline = "Your booking is confirmed."
        case .inProgress: headline = "We've started work on your vehicle."
        case .completed: headline = "Your service is complete."
        case .rejected: headline = "Unfortunately we can't take this booking. Please choose another time."
        case .pending: headline = "Your booking is being reviewed."
        }
        return ("Your booking – \(a.status.rawValue)",
                """
                Hi \(a.customerName),

                \(headline)

                Service: \(a.service.rawValue)
                Vehicle: \(a.vehicleTitle)
                When: \(a.date.formatted(date: .complete, time: .shortened))\(mechanic)

                – \(a.garage)
                """)
    }

    static func receipt(_ r: Receipt) -> EmailContent {
        let lines = r.lines.map { "• \($0.title) – \($0.quantity) × \(rs($0.unitPrice)) = \(rs($0.amount))" }
            .joined(separator: "\n")
        return ("Receipt \(r.number) – \(r.garage)",
                """
                Hi \(r.customerName),

                Thank you for choosing \(r.garage). Your service on \(r.vehicleTitle) is complete.

                \(lines)

                Total: \(rs(r.total))

                Your receipt is attached as a PDF.

                – \(r.garage)
                """)
    }
}
