//
//  FlightsMapView.swift
//  Universal Search App
//
//  Live Apple Map shown behind the flights results sheet. The sheet can be
//  dragged down to reveal it. Plots the route's origin/destination airports and
//  a connecting line, framed to fit both endpoints.
//

import SwiftUI
import MapKit

/// Known airport coordinates for the baked destinations (origin + covered cities).
enum AirportCoords {
    static let table: [String: CLLocationCoordinate2D] = [
        "IAH": .init(latitude: 29.9902, longitude: -95.3368),
        "HOU": .init(latitude: 29.6454, longitude: -95.2789),
        "JFK": .init(latitude: 40.6413, longitude: -73.7781),
        "EWR": .init(latitude: 40.6895, longitude: -74.1745),
        "NYC": .init(latitude: 40.6413, longitude: -73.7781),
        "CUN": .init(latitude: 21.0365, longitude: -86.8771),
        "SJD": .init(latitude: 23.1518, longitude: -109.7215),
        "PVR": .init(latitude: 20.6801, longitude: -105.2544),
        "TQO": .init(latitude: 20.2409, longitude: -87.5966),
        "LAX": .init(latitude: 33.9416, longitude: -118.4085),
        "TPA": .init(latitude: 27.9755, longitude: -82.5332),
    ]
    static func coord(_ code: String) -> CLLocationCoordinate2D? { table[code.uppercased()] }
}

struct FlightsMapView: View {
    let route: FlightRoute?
    /// Draw city-name label capsules alongside the pins (composer collapsed card).
    var labelled: Bool = false

    private var points: [MapPoint] {
        var result: [MapPoint] = []
        if let route, let a = AirportCoords.coord(route.originCode) {
            result.append(MapPoint(coordinate: a, label: route.originCity,
                                   icon: labelled ? "house.fill" : "airplane.departure",
                                   showsLabel: labelled))
        }
        if let route, let b = AirportCoords.coord(route.destCode) {
            result.append(MapPoint(coordinate: b, label: route.destCity,
                                   icon: labelled ? nil : "airplane.arrival",
                                   showsLabel: labelled))
        }
        return result
    }

    var body: some View {
        CanvasMapView(points: points, connect: !labelled)
    }
}
