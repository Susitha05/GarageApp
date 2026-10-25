import SwiftUI
import MapKit

struct DriverActiveJobView: View {
    @Environment(AppState.self) private var app

    private var job: TowRequest? { app.towRequests.first { $0.id == app.activeJobID } }

    var body: some View {
        NavigationStack {
            Group {
                if let job {
                    ZStack(alignment: .bottom) {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: job.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)))) {
                            Marker(job.customerName, systemImage: "car.fill", coordinate: job.coordinate).tint(.red)
                        }
                        Card {
                            HStack {
                                Text(job.customerName).font(.headline)
                                Spacer()
                                StatusBadge(text: job.status.rawValue, color: job.status.color)
                            }
                            Label(job.address, systemImage: "mappin.and.ellipse").font(.subheadline)
                            if let next = job.status.next {
                                Button { app.advanceActiveJob() } label: {
                                    Text("Update status: \(next.rawValue)").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("No active job", systemImage: "truck.box",
                                           description: Text("Accept a job from the Jobs tab to start navigation."))
                }
            }
            .navigationTitle("Active Job")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("With active job") {
    let state = AppState(role: .towDriver)
    state.acceptJob(state.towRequests[0].id)
    return DriverActiveJobView().environment(state)
}

#Preview("No active job") { DriverActiveJobView().environment(AppState(role: .towDriver)) }
