import SwiftUI
import Charts

struct GarageDashboardView: View {
    @Environment(AppState.self) private var app

    private var pending: Int { app.appointments.filter { $0.status == .pending }.count }
    private var lowStock: Int { app.inventory.filter(\.isLow).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Pending bookings", value: "\(pending)", icon: "clock.fill", tint: .orange)
                        StatTile(title: "Low-stock parts", value: "\(lowStock)", icon: "exclamationmark.triangle.fill", tint: .red)
                        StatTile(title: "This month", value: rs(540_000), icon: "banknote.fill", tint: .green)
                        StatTile(title: "Active staff", value: "\(app.staff.count)", icon: "person.2.fill")
                    }

                    SectionTitle("Revenue & forecast")
                    Card {
                        Chart(app.revenue) { p in
                            BarMark(x: .value("Month", p.month), y: .value("Revenue", p.amount))
                                .foregroundStyle(p.isForecast ? Color.orange : Color.blue)
                        }
                        .frame(height: 200)
                        .accessibilityLabel("Monthly revenue with forecast for the next two months")
                        Text(MLService.shared.revenueLoaded ? "Forecast by on-device Core ML" : "Forecast: simple trend (model not bundled)")
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Label("Actual", systemImage: "square.fill").foregroundStyle(.blue)
                            Label("Forecast", systemImage: "square.fill").foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("AutoCare Garage")
        }
    }
}

#Preview { GarageDashboardView().environment(AppState(role: .garageOwner)) }
