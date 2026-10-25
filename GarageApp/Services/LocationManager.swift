import Foundation
import CoreLocation
import MapKit

/// Wraps CLLocationManager: permission, live updates, reverse geocoding and a simple geofence.
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let fallback = CLLocationCoordinate2D(latitude: 7.2085, longitude: 79.8358) // Negombo

    var location: CLLocation?
    var authorization: CLAuthorizationStatus
    var address: String?
    var arrivedRegionID: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private var lastGeocode: Date = .distantPast
    @ObservationIgnored private var geofence: (id: String, center: CLLocationCoordinate2D, radius: Double)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    var coordinate: CLLocationCoordinate2D { location?.coordinate ?? Self.fallback }
    var isLive: Bool { location != nil }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    var statusText: String {
        if isDenied { return "Location access denied – enable it in Settings" }
        if isLive { return address ?? "Live location" }
        return "Using sample location"
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        default: break
        }
    }

    func stop() { manager.stopUpdatingLocation() }

    func distanceKm(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let location else { return nil }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) / 1000
    }

    // MARK: Geofencing
    func startGeofence(id: String, center: CLLocationCoordinate2D, radius: Double = 150) {
        arrivedRegionID = nil
        geofence = (id, center, radius)
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(center: center,
                                      radius: min(radius, manager.maximumRegionMonitoringDistance),
                                      identifier: id)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
    }

    // MARK: CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        location = latest

        // Foreground geofence check (works with "When In Use" permission).
        if let g = geofence,
           latest.distance(from: CLLocation(latitude: g.center.latitude, longitude: g.center.longitude)) <= g.radius {
            arrivedRegionID = g.id
        }

        // Reverse-geocode at most every 30 s.
        if Date().timeIntervalSince(lastGeocode) > 30, !geocoder.isGeocoding {
            lastGeocode = Date()
            geocoder.reverseGeocodeLocation(latest) { [weak self] marks, _ in
                guard let p = marks?.first else { return }
                self?.address = [p.name, p.locality].compactMap { $0 }.joined(separator: ", ")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        arrivedRegionID = region.identifier
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// Driving route + ETA via MapKit.
enum RoutingService {
    static func route(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        return try? await MKDirections(request: request).calculate().routes.first
    }

    static func openInMaps(_ coordinate: CLLocationCoordinate2D, name: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
