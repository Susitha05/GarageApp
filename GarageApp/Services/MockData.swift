import Foundation

enum MockData {
    static let cal = Calendar.current
    static func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: .now) ?? .now }

    static let vehicles: [Vehicle] = [
        Vehicle(registration: "CAB-4821", make: "Toyota", model: "Axio", year: 2016, mileage: 78_400),
        Vehicle(registration: "KV-7733", make: "Honda", model: "Vezel", year: 2019, mileage: 42_150)
    ]

    static let records: [ServiceRecord] = [
        ServiceRecord(vehicleID: vehicles[0].id, title: "Oil Change", date: days(-60), mileage: 76_000, cost: 12_500, garage: "AutoCare Garage", parts: ["Engine Oil"]),
        ServiceRecord(vehicleID: vehicles[0].id, title: "Brake Pad Replacement", date: days(-210), mileage: 62_000, cost: 28_000, garage: "AutoCare Garage", parts: ["Brake Pads"]),
        ServiceRecord(vehicleID: vehicles[0].id, title: "Battery Replacement", date: days(-400), mileage: 50_000, cost: 34_000, garage: "Power Motors", parts: ["Battery"]),
        ServiceRecord(vehicleID: vehicles[1].id, title: "Full Service", date: days(-90), mileage: 40_000, cost: 45_000, garage: "AutoCare Garage", parts: ["Engine Oil", "Air Filter"])
    ]

    static let appointments: [Appointment] = [
        Appointment(customerName: "Nimal Perera", vehicleTitle: "2016 Toyota Axio", service: .oilChange, date: days(1), status: .pending, noShowRisk: 0.12),
        Appointment(customerName: "Kasun Silva", vehicleTitle: "2019 Honda Vezel", service: .brakeService, date: days(1), status: .accepted, assignedStaff: "Ruwan Kumara", noShowRisk: 0.46, bookedDaysAhead: 14, pastNoShows: 1),
        Appointment(customerName: "Dilani Fernando", vehicleTitle: "2014 Nissan Leaf", service: .batteryCheck, date: days(2), status: .pending, noShowRisk: 0.71, bookedDaysAhead: 25, pastNoShows: 2, isFirstVisit: true),
        Appointment(customerName: "Sahan Jayasuriya", vehicleTitle: "2018 Suzuki Wagon R", service: .fullService, date: days(0), status: .inProgress, assignedStaff: "Chamara Dias", noShowRisk: 0.05),
        Appointment(customerName: "Amali Weerasinghe", vehicleTitle: "2020 Kia Picanto", service: .acService, date: days(-1), status: .completed, assignedStaff: "Ruwan Kumara", noShowRisk: 0.08)
    ]

    static let inventory: [InventoryItem] = [
        InventoryItem(name: "Engine Oil 5W-30 (4L)", sku: "OIL-530", stock: 18, minThreshold: 10, usedThisMonth: 24, forecastNextMonth: 28, unitPrice: 4500),
        InventoryItem(name: "Brake Pads (Front)", sku: "BRK-F01", stock: 6, minThreshold: 8, usedThisMonth: 11, forecastNextMonth: 13, unitPrice: 9500),
        InventoryItem(name: "Oil Filter", sku: "FLT-OIL", stock: 32, minThreshold: 15, usedThisMonth: 26, forecastNextMonth: 27, unitPrice: 1200),
        InventoryItem(name: "Car Battery 12V", sku: "BAT-12V", stock: 3, minThreshold: 4, usedThisMonth: 5, forecastNextMonth: 7, unitPrice: 22000),
        InventoryItem(name: "Air Filter", sku: "FLT-AIR", stock: 14, minThreshold: 8, usedThisMonth: 9, forecastNextMonth: 10, unitPrice: 1800)
    ]

    static let staff: [StaffMember] = [
        StaffMember(name: "Ruwan Kumara", role: "Senior Mechanic", assignedJobs: 7, completedJobs: 42),
        StaffMember(name: "Chamara Dias", role: "Mechanic", assignedJobs: 4, completedJobs: 31),
        StaffMember(name: "Isuru Bandara", role: "Technician", assignedJobs: 2, completedJobs: 18)
    ]

    static let towRequests: [TowRequest] = [
        TowRequest(customerName: "Nimal Perera", vehicleTitle: "2016 Toyota Axio", address: "Colombo Rd, Negombo", latitude: 7.2085, longitude: 79.8358, status: .requested),
        TowRequest(customerName: "Priya Nair", vehicleTitle: "2017 Honda Fit", address: "Airport Rd, Katunayake", latitude: 7.1750, longitude: 79.8860, status: .requested)
    ]

    static let expenses: [ExpenseEntry] = [
        ExpenseEntry(title: "Oil Change", amount: 12_500, date: days(-60), category: "Service"),
        ExpenseEntry(title: "Brake Pads", amount: 28_000, date: days(-210), category: "Parts"),
        ExpenseEntry(title: "Fuel", amount: 18_000, date: days(-10), category: "Fuel"),
        ExpenseEntry(title: "Insurance", amount: 52_000, date: days(-120), category: "Insurance"),
        ExpenseEntry(title: "Tyre Rotation", amount: 4_500, date: days(-30), category: "Service"),
        ExpenseEntry(title: "Fuel", amount: 16_500, date: days(-40), category: "Fuel")
    ]

    static let revenue: [RevenuePoint] = [
        RevenuePoint(month: "May", amount: 410_000), RevenuePoint(month: "Jun", amount: 455_000),
        RevenuePoint(month: "Jul", amount: 430_000), RevenuePoint(month: "Aug", amount: 498_000),
        RevenuePoint(month: "Sep", amount: 520_000), RevenuePoint(month: "Oct", amount: 540_000)
    ]

    static let garages: [GarageInfo] = [
        GarageInfo(name: "AutoCare Garage", latitude: 7.2100, longitude: 79.8420),
        GarageInfo(name: "Power Motors", latitude: 7.1900, longitude: 79.8600),
        GarageInfo(name: "Negombo Auto Works", latitude: 7.2300, longitude: 79.8300)
    ]

    static let notifications: [AppNotification] = [
        AppNotification(title: "Booking confirmed", body: "Oil Change at AutoCare Garage, tomorrow 10:00 AM.", date: days(0), icon: "checkmark.circle.fill"),
        AppNotification(title: "Maintenance due soon", body: "Brake pads on your Axio are predicted to need replacing soon.", date: days(-1), icon: "wrench.fill"),
        AppNotification(title: "Tow driver on the way", body: "Driver Saman is 8 minutes away.", date: days(-3), icon: "truck.box.fill")
    ]

    static let anomalies: [Anomaly] = [
        Anomaly(title: "Repeated brake repairs – Honda Vezel", detail: "3 brake jobs in 4 months across 2 vehicles of the same model.", risk: .high),
        Anomaly(title: "Battery failures up 40%", detail: "Unusual rise in 12V battery replacements this month.", risk: .medium)
    ]
}
