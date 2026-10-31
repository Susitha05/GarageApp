import XCTest
import CoreLocation
@testable import GarageApp

/// Tests the logic inside LocationManager without needing real GPS.
/// Each test uses its own LocationManager() so the shared one is not disturbed.
final class LocationManagerTests: XCTestCase {

    private let center = CLLocationCoordinate2D(latitude: 7.2085, longitude: 79.8358)

    private func update(_ lm: LocationManager, to c: CLLocationCoordinate2D) {
        lm.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: c.latitude, longitude: c.longitude)])
    }

    // MARK: - Authorization flags and status text
    func testAuthorizationFlags() {
        let lm = LocationManager()

        lm.authorization = .denied
        XCTAssertTrue(lm.isDenied)
        XCTAssertFalse(lm.isAuthorized)
        XCTAssertTrue(lm.statusText.contains("denied"))

        lm.authorization = .restricted
        XCTAssertTrue(lm.isDenied)

        lm.authorization = .authorizedWhenInUse
        XCTAssertTrue(lm.isAuthorized)
        XCTAssertFalse(lm.isDenied)

        lm.authorization = .authorizedAlways
        XCTAssertTrue(lm.isAuthorized)
    }

    func testStatusTextWhileWaitingForPermissionOrGPS() {
        let lm = LocationManager()
        lm.authorization = .notDetermined
        XCTAssertEqual(lm.statusText, "Allow location access to continue")

        lm.authorization = .authorizedWhenInUse
        XCTAssertEqual(lm.statusText, "Finding your location…")
    }

    func testStatusTextUsesTheAddressWhenKnown() {
        let lm = LocationManager()
        lm.authorization = .authorizedWhenInUse
        lm.location = CLLocation(latitude: 7.0, longitude: 79.0)
        XCTAssertEqual(lm.statusText, "Live location")
        lm.address = "Galle Rd, Colombo"
        XCTAssertEqual(lm.statusText, "Galle Rd, Colombo")
    }

    // MARK: - Coordinates, sample location and distance
    func testFallbackCoordinateWhenThereIsNoFix() {
        let lm = LocationManager()
        XCTAssertFalse(lm.isLive)
        XCTAssertEqual(lm.coordinate.latitude, LocationManager.fallback.latitude, accuracy: 0.0001)
        XCTAssertEqual(lm.coordinate.longitude, LocationManager.fallback.longitude, accuracy: 0.0001)
    }

    func testSampleLocation() {
        let lm = LocationManager()
        lm.authorization = .authorizedWhenInUse
        lm.useSampleLocation()
        XCTAssertTrue(lm.isSampleLocation)
        XCTAssertTrue(lm.isLive)
        XCTAssertEqual(lm.address, "Colombo Rd, Negombo")
        XCTAssertEqual(lm.statusText, "Sample location (testing)")
    }

    func testDistanceInKilometres() {
        let lm = LocationManager()
        XCTAssertNil(lm.distanceKm(to: center))                       // no fix yet

        lm.location = CLLocation(latitude: 7.0, longitude: 79.0)
        let oneDegreeNorth = CLLocationCoordinate2D(latitude: 8.0, longitude: 79.0)
        XCTAssertEqual(lm.distanceKm(to: oneDegreeNorth) ?? 0, 111, accuracy: 1.5)
        XCTAssertEqual(lm.distanceKm(to: CLLocationCoordinate2D(latitude: 7.0, longitude: 79.0)) ?? 1, 0, accuracy: 0.01)
    }

    func testStopClearsTheState() {
        let lm = LocationManager()
        lm.useSampleLocation()
        lm.stop()
        XCTAssertNil(lm.location)
        XCTAssertNil(lm.address)
        XCTAssertFalse(lm.isSampleLocation)
    }

    // MARK: - Errors
    func testGPSNotReadyMessage() {
        let lm = LocationManager()
        lm.authorization = .authorizedWhenInUse
        lm.locationManager(CLLocationManager(), didFailWithError: NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue))
        XCTAssertTrue(lm.statusText.contains("Waiting for GPS"))
    }

    func testOtherErrorsShowTheirDescription() {
        let lm = LocationManager()
        lm.authorization = .authorizedWhenInUse
        let error = NSError(domain: "Test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Boom"])
        lm.locationManager(CLLocationManager(), didFailWithError: error)
        XCTAssertEqual(lm.statusText, "Boom")
    }

    // MARK: - Geofence (arrival detection)
    func testArrivalIsDetectedInsideTheGeofence() {
        let lm = LocationManager()
        lm.startGeofence(id: "job-1", center: center, radius: 150)
        XCTAssertNil(lm.arrivedRegionID)
        update(lm, to: center)
        XCTAssertEqual(lm.arrivedRegionID, "job-1")
    }

    func testNoArrivalOutsideTheGeofence() {
        let lm = LocationManager()
        lm.startGeofence(id: "job-1", center: center, radius: 150)
        update(lm, to: CLLocationCoordinate2D(latitude: center.latitude + 1, longitude: center.longitude))
        XCTAssertNil(lm.arrivedRegionID)
    }

    func testStartingANewGeofenceClearsTheOldArrival() {
        let lm = LocationManager()
        lm.arrivedRegionID = "old-job"
        lm.startGeofence(id: "new-job", center: center)
        XCTAssertNil(lm.arrivedRegionID)
    }

    func testEnteringARegionSetsTheArrivalFlag() {
        let lm = LocationManager()
        let region = CLCircularRegion(center: center, radius: 100, identifier: "job-2")
        lm.locationManager(CLLocationManager(), didEnterRegion: region)
        XCTAssertEqual(lm.arrivedRegionID, "job-2")
    }
}
