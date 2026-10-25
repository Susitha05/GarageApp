import SwiftUI
import Charts

struct ExpensesView: View {
    @Environment(AppState.self) private var app
    @State private var showScanNote = false

    private var byCategory: [(category: String, total: Double)] {
        Dictionary(grouping: app.expenses, by: \.category)
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        List {
            Section("Spending by category") {
                Chart(byCategory, id: \.category) { item in
                    BarMark(x: .value("Category", item.category), y: .value("Amount", item.total))
                        .foregroundStyle(by: .value("Category", item.category))
                }
                .frame(height: 200)
                .accessibilityLabel("Bar chart of spending by category")
            }
            Section("Recent") {
                ForEach(app.expenses.sorted { $0.date > $1.date }) { e in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(e.title)
                            Text(e.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rs(e.amount)).font(.subheadline.weight(.semibold))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Expenses")
        .toolbar {
            Button { showScanNote = true } label: { Image(systemName: "doc.viewfinder") }
                .accessibilityLabel("Scan receipt")
        }
        .alert("Receipt scanning", isPresented: $showScanNote) {
            Button("OK", role: .cancel) {}
        } message: { Text("Vision / VisionKit scanning will be wired in here.") }
    }
}

#Preview { NavigationStack { ExpensesView() }.environment(AppState(role: .customer)) }
