import AppIntents

// Reads the same WidgetSnapshot your app already saves for the widget.

// MARK: - 1. "When is my next service?"
struct NextServiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Next service due"
    static var description = IntentDescription("Tells you the next predicted maintenance for your vehicle.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let s = WidgetSnapshotStore.load() else {
            return .result(dialog: IntentDialog(stringLiteral: "Open the app and add a vehicle first."))
        }
        let text = s.dueInKm <= 0
            ? "Your \(s.vehicleName) is overdue for \(s.topPart). Risk level is \(s.risk)."
            : "Your \(s.vehicleName) needs \(s.topPart) in about \(s.dueInKm) kilometres."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: - 2. "What is my next appointment?"
struct NextAppointmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Next appointment"
    static var description = IntentDescription("Tells you your next garage appointment.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let s = WidgetSnapshotStore.load(), let title = s.nextAppointmentTitle else {
            return .result(dialog: IntentDialog(stringLiteral: "You have no upcoming appointments."))
        }
        let when = s.nextAppointmentDate?.formatted(date: .abbreviated, time: .shortened) ?? "soon"
        return .result(dialog: IntentDialog(stringLiteral: "Your next appointment is \(title), on \(when)."))
    }
}

// MARK: - 3. "Where is my tow truck?"
struct TowStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Tow status"
    static var description = IntentDescription("Tells you the status of your tow request.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = WidgetSnapshotStore.load()?.towStatus ?? ""
        let text = status.isEmpty ? "You have no active tow request." : "Your tow status is: \(status)."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: - 4. "Request a tow" (opens the app)
struct RequestTowIntent: AppIntent {
    static var title: LocalizedStringResource = "Request a tow"
    static var description = IntentDescription("Opens the app so you can request a tow.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set("tow", forKey: "pendingTab")
        return .result()
    }
}

// MARK: - Siri phrases (each must contain the app name exactly once)
struct GarageShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NextServiceIntent(),
                    phrases: ["When is my next service in \(.applicationName)",
                              "What maintenance is due in \(.applicationName)",
                              "Check my car in \(.applicationName)"],
                    shortTitle: "Next service", systemImageName: "wrench.and.screwdriver")
        AppShortcut(intent: NextAppointmentIntent(),
                    phrases: ["What is my next appointment in \(.applicationName)",
                              "Next booking in \(.applicationName)"],
                    shortTitle: "Next appointment", systemImageName: "calendar")
        AppShortcut(intent: TowStatusIntent(),
                    phrases: ["Where is my tow truck in \(.applicationName)",
                              "Tow status in \(.applicationName)"],
                    shortTitle: "Tow status", systemImageName: "truck.box")
        AppShortcut(intent: RequestTowIntent(),
                    phrases: ["Request a tow in \(.applicationName)",
                              "I need a tow in \(.applicationName)"],
                    shortTitle: "Request tow", systemImageName: "exclamationmark.triangle")
    }
}
