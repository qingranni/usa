//
//  CanvasMapView.swift
//  Universal Search App
//
//  Reusable live Apple Map used behind the flights results sheet and inside the
//  composer's collapsed canvas card. Plots a set of labelled points and an
//  optional connecting line, framed to fit all of them.
//

import SwiftUI
import MapKit
import CoreLocation

/// A labelled point on the canvas map.
struct MapPoint: Identifiable {
    var coordinate: CLLocationCoordinate2D
    var label: String
    /// Stable identity derived from the content — the points array is rebuilt on
    /// every reveal-scrub frame, and a stored UUID would tear down and recreate
    /// the Map's annotations each time.
    var id: String { "\(label)-\(coordinate.latitude)-\(coordinate.longitude)" }
    /// SF Symbol drawn inside the pin. When nil the point renders as a small dot.
    var icon: String?
    /// When true the label capsule rides alongside the pin (Figma city pills).
    var showsLabel: Bool
}

struct CanvasMapView: View {
    var points: [MapPoint]
    /// Draw a connecting line through the points in order.
    var connect: Bool = false
    /// Explicit region (single-city framing); overrides the auto-fit below.
    var regionOverride: MKCoordinateRegion? = nil
    /// Multiplies the 3D route camera distance so the collapsed composer card can
    /// zoom the same route map out a little.
    var distanceScale: CGFloat = 1

    private var region: MKCoordinateRegion {
        regionOverride ?? Self.autoRegion(for: points.map(\.coordinate))
    }

    /// Auto-fit region framing all the given coordinates: a tight span for a lone
    /// pin, padded route framing for two or more. Shared with `MapSpec` so baked
    /// route/city map framing stays in one place.
    static func autoRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coords.first else {
            return MKCoordinateRegion(center: .init(latitude: 32, longitude: -95),
                                      span: .init(latitudeDelta: 40, longitudeDelta: 45))
        }
        // A lone pin (city page) frames tight instead of the wide route padding.
        if coords.count == 1 {
            return MKCoordinateRegion(center: first,
                                      span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let latDelta = (maxLat - minLat) * 1.8 + 6
        let lonDelta = (maxLon - minLon) * 1.8 + 6
        return MKCoordinateRegion(center: center,
                                  span: .init(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    /// Look-at centre for the 3D camera. Biased toward the southern (near) end
    /// so both endpoints clear the results sheet that covers the lower screen.
    private var routeCenter: CLLocationCoordinate2D {
        let coords = points.map(\.coordinate)
        guard let first = coords.first else { return region.center }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        // Bias south of the true midpoint: the pitched camera pushes the far
        // (north) end up-screen, so pulling the look-at down keeps the near
        // (south) pin from hiding behind the sheet.
        return CLLocationCoordinate2D(latitude: minLat + (maxLat - minLat) * 0.38,
                                      longitude: (minLon + maxLon) / 2)
    }

    /// Eye-to-ground distance sized to keep the full route span in frame while
    /// steeply pitched. Scales off the widest gap between any two points.
    private var routeDistance: CLLocationDistance {
        let locs = points.map { CLLocation(latitude: $0.coordinate.latitude,
                                           longitude: $0.coordinate.longitude) }
        var maxGap: CLLocationDistance = 0
        for i in locs.indices {
            for j in locs.indices where j > i {
                maxGap = max(maxGap, locs[i].distance(from: locs[j]))
            }
        }
        // A steep tilt compresses the vertical field, so pull the camera well
        // back to keep both endpoints visible above the sheet.
        return (maxGap * 4.0 + 350_000) * distanceScale
    }

    /// Steep tilt applied to the 3D route camera.
    private let routePitch: Double = 70

    /// 3D framing: a lone city keeps its tight region; a route tilts the camera
    /// steeply back and frames the whole span from end to end.
    private var initialPosition: MapCameraPosition {
        if let regionOverride { return .region(regionOverride) }
        if points.count >= 2 {
            return .camera(MapCamera(centerCoordinate: routeCenter,
                                     distance: routeDistance,
                                     heading: 0,
                                     pitch: routePitch))
        }
        return .region(region)
    }

    /// Screen positions of the route endpoints, refreshed as the camera moves so
    /// the arched flight path stays pinned to the origin/destination markers.
    @State private var arcStart: CGPoint? = nil
    @State private var arcEnd: CGPoint? = nil

    var body: some View {
        MapReader { proxy in
            Map(initialPosition: initialPosition) {
                ForEach(points) { point in
                    Annotation("", coordinate: point.coordinate) {
                        marker(point)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .overlay {
                if connect, let start = arcStart, let end = arcEnd {
                    ZStack {
                        // Ground track: where the route meets the terrain. This is
                        // the arc's cast shadow, so the bowed line visibly lifts
                        // off it toward the middle of the span.
                        GroundTrack(start: start, end: end)
                            .stroke(Color.black.opacity(0.28),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .blur(radius: 2.5)

                        // Faint drop lines from the arc down to the ground track
                        // give the altitude a readable, three-dimensional gap.
                        ArcDropLines(start: start, end: end)
                            .stroke(Theme.figmaInk.opacity(0.28),
                                    style: StrokeStyle(lineWidth: 1, lineCap: .round))

                        FlightArc(start: start, end: end)
                            .stroke(Theme.figmaInk,
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear { updateArc(proxy) }
            .onMapCameraChange(frequency: .continuous) { _ in updateArc(proxy) }
        }
    }

    /// Reprojects the first/last route coordinates into the map's local screen
    /// space. Clears the arc when either endpoint isn't currently on screen.
    private func updateArc(_ proxy: MapProxy) {
        guard connect, points.count >= 2,
              let a = points.first?.coordinate,
              let b = points.last?.coordinate else {
            arcStart = nil; arcEnd = nil
            return
        }
        arcStart = proxy.convert(a, to: .local)
        arcEnd = proxy.convert(b, to: .local)
    }

    @ViewBuilder
    private func marker(_ point: MapPoint) -> some View {
        if point.showsLabel {
            HStack(spacing: 8) {
                if let icon = point.icon {
                    EGDSIcon(icon, size: 15)
                        .foregroundStyle(Theme.figmaInk)
                }
                Text(point.label)
                    .font(.centra(size: 14, weight: point.icon == nil ? .regular : .medium))
                    .foregroundStyle(Theme.figmaInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.8), in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        } else if let icon = point.icon {
            pin(system: icon)
        } else {
            Circle()
                .fill(Theme.figmaInk)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        }
    }

    private func pin(system: String) -> some View {
        ZStack {
            Circle().fill(.white)
            Circle().strokeBorder(Theme.figmaInk.opacity(0.15), lineWidth: 1)
            EGDSIcon(system, size: 16)
                .foregroundStyle(Theme.figmaInk)
        }
        .frame(width: 30, height: 30)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

/// Shared geometry for the flight-path arc so the arc, its ground track, and the
/// drop lines all agree on where the curve sits.
enum ArcGeometry {
    /// Quadratic-bezier control point, offset perpendicular to the chord toward
    /// the top of the screen so the arc bows upward like an altitude profile.
    static func control(start: CGPoint, end: CGPoint, heightFactor: CGFloat) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.0001)
        var nx = -dy / length
        var ny = dx / length
        if ny > 0 { nx = -nx; ny = -ny }
        let lift = length * heightFactor
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        return CGPoint(x: mid.x + nx * lift, y: mid.y + ny * lift)
    }

    /// Point on the quadratic bezier at parameter `t` in [0, 1].
    static func point(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * start.x + 2 * u * t * control.x + t * t * end.x
        let y = u * u * start.y + 2 * u * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }
}

/// A quadratic-bezier flight path between two screen points, bowed toward the
/// top of the screen so it reads as a 3D arc rising above the tilted terrain.
struct FlightArc: Shape {
    var start: CGPoint
    var end: CGPoint
    /// Arc apex height as a fraction of the endpoint distance.
    var heightFactor: CGFloat = 0.22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let control = ArcGeometry.control(start: start, end: end, heightFactor: heightFactor)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

/// The straight chord between the endpoints: the arc's footprint on the ground,
/// drawn as a soft shadow so the arc reads as lifted above it.
struct GroundTrack: Shape {
    var start: CGPoint
    var end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

/// Vertical connectors from points along the arc down to the ground track,
/// making the altitude gap explicit for a stronger 3D read.
struct ArcDropLines: Shape {
    var start: CGPoint
    var end: CGPoint
    var heightFactor: CGFloat = 0.22
    /// Fractions along the span where a drop line is drawn.
    var stops: [CGFloat] = [0.25, 0.5, 0.75]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let control = ArcGeometry.control(start: start, end: end, heightFactor: heightFactor)
        for t in stops {
            let top = ArcGeometry.point(start: start, control: control, end: end, t: t)
            let ground = CGPoint(x: start.x + (end.x - start.x) * t,
                                 y: start.y + (end.y - start.y) * t)
            path.move(to: top)
            path.addLine(to: ground)
        }
        return path
    }
}

/// City-centre coordinates for the baked destinations, used to frame the map +
/// results combo on the non-flight pages (hotels / cars / things to do). The
/// multi-city "Mexico" bucket gets a broad span; the rest a city-level zoom.
enum CityCoords {
    struct Entry {
        let name: String
        let coord: CLLocationCoordinate2D
        let span: CLLocationDegrees
    }

    static let table: [Entry] = [
        Entry(name: "Cabo San Lucas",   coord: .init(latitude: 22.8905, longitude: -109.9167), span: 0.5),
        Entry(name: "Puerto Vallarta",  coord: .init(latitude: 20.6534, longitude: -105.2253), span: 0.5),
        Entry(name: "Playa del Carmen", coord: .init(latitude: 20.6296, longitude: -87.0739),  span: 0.4),
        Entry(name: "Los Angeles",      coord: .init(latitude: 34.0522, longitude: -118.2437), span: 0.6),
        Entry(name: "Cancún",           coord: .init(latitude: 21.1619, longitude: -86.8515),  span: 0.5),
        Entry(name: "Cancun",           coord: .init(latitude: 21.1619, longitude: -86.8515),  span: 0.5),
        Entry(name: "Tulum",            coord: .init(latitude: 20.2114, longitude: -87.4654),  span: 0.4),
        Entry(name: "Tampa",            coord: .init(latitude: 27.9506, longitude: -82.4572),  span: 0.5),
        Entry(name: "Mexico",           coord: .init(latitude: 23.6345, longitude: -102.5528), span: 20),
    ]

    /// Longest names win so "Cabo San Lucas" matches before a bare "Cabo".
    /// Presorted once — `resolve` runs on every reveal-scrub frame via
    /// `CanvasMapView.forThread`.
    private static let byLengthDesc = table.sorted { $0.name.count > $1.name.count }

    static func resolve(from title: String) -> Entry? {
        let lower = title.lowercased()
        return byLengthDesc.first { lower.contains($0.name.lowercased()) }
    }
}

/// The framing inputs a thread's results map derives from — shared by the
/// full-screen `CanvasMapView` path and any future compact map surfaces.
struct MapSpec {
    var points: [MapPoint]
    /// Draw a connecting line through the points (flight route).
    var connect: Bool
    /// Resolved region for flat map framing. Live routes use the points for a 3D
    /// camera, but keep this region for consistent existence/framing logic.
    var region: MKCoordinateRegion

    /// The baked map framing for a thread: a flight route (two pins) or a baked
    /// destination city (a single pin). Returns nil when the thread has no baked
    /// location; `ResultsMapView` can still use the geocoded `PlaceMapView`.
    @MainActor
    static func forThread(_ thread: ThreadNode) -> MapSpec? {
        switch thread.kind {
        case .flights:
            guard let route = FlightRoute(thread.activeCards.first?.title) else { return nil }
            var pts: [MapPoint] = []
            if let a = AirportCoords.coord(route.originCode) {
                pts.append(MapPoint(coordinate: a, label: route.originCity,
                                    icon: "airplane.departure", showsLabel: false))
            }
            if let b = AirportCoords.coord(route.destCode) {
                pts.append(MapPoint(coordinate: b, label: route.destCity,
                                    icon: "airplane.arrival", showsLabel: false))
            }
            guard !pts.isEmpty else { return nil }
            return MapSpec(points: pts, connect: true,
                           region: CanvasMapView.autoRegion(for: pts.map(\.coordinate)))

        case .lodging, .cars, .activities:
            guard let city = CityCoords.resolve(from: thread.title) else { return nil }
            let pt = MapPoint(coordinate: city.coord, label: city.name,
                              icon: "mappin", showsLabel: false)
            return MapSpec(points: [pt], connect: false,
                           region: MKCoordinateRegion(
                            center: city.coord,
                            span: .init(latitudeDelta: city.span, longitudeDelta: city.span)))

        case .other:
            // The broad Mexico/package view from Figma uses a regional map with
            // the origin and representative destinations labelled in place.
            guard thread.title.localizedCaseInsensitiveContains("mexico") else { return nil }
            let points = [
                MapPoint(coordinate: .init(latitude: 29.7604, longitude: -95.3698),
                         label: "Houston", icon: "house", showsLabel: true),
                MapPoint(coordinate: .init(latitude: 20.6534, longitude: -105.2253),
                         label: "Puerto Vallarta", icon: nil, showsLabel: true),
                MapPoint(coordinate: .init(latitude: 21.1619, longitude: -86.8515),
                         label: "Cancun", icon: nil, showsLabel: true),
            ]
            return MapSpec(
                points: points,
                connect: false,
                region: MKCoordinateRegion(
                    center: .init(latitude: 28.5, longitude: -97),
                    span: .init(latitudeDelta: 25, longitudeDelta: 25)
                )
            )

        }
    }
}

extension CanvasMapView {
    /// Memo for `forThread` — RootView and CurtainSheet both ask for the map on
    /// every reveal-scrub frame, and each build re-parses the route / re-resolves
    /// the city. Keyed on exactly the inputs the map derives from, so it refreshes
    /// naturally when a refinement changes the thread's results.
    @MainActor private static var built: [String: CanvasMapView?] = [:]

    /// Builds the results-page map for a thread: the flight route (two pins + a
    /// connecting line) or the destination city (a single pin). Returns nil when
    /// the thread has no mappable location, so the caller keeps the plain sheet.
    /// `zoom` (>1) widens the framing so the composer's collapsed card can show
    /// the same map, just pulled back a little.
    @MainActor
    static func forThread(_ thread: ThreadNode, zoom: CGFloat = 1) -> CanvasMapView? {
        let key = "\(thread.id)|\(thread.kind)|\(thread.activeCards.first?.title ?? "")|\(thread.title)|\(zoom)"
        if let hit = built[key] { return hit }
        let map = build(thread, zoom: zoom)
        built[key] = map
        return map
    }

    private static func build(_ thread: ThreadNode, zoom: CGFloat) -> CanvasMapView? {
        guard let spec = MapSpec.forThread(thread) else { return nil }
        if spec.connect {
            // Routes tilt a 3D camera framed from the points, so no region override.
            return CanvasMapView(points: spec.points, connect: true, distanceScale: zoom)
        }
        // A lone city frames tight; the composer's collapsed card pulls back (>1).
        let span = spec.region.span.latitudeDelta * zoom
        return CanvasMapView(points: spec.points, connect: false,
                             regionOverride: MKCoordinateRegion(
                                center: spec.region.center,
                                span: .init(latitudeDelta: span, longitudeDelta: span)))
    }

    /// Whether `thread` has a results-page map behind its detent sheet.
    @MainActor
    static func exists(for thread: ThreadNode) -> Bool { forThread(thread) != nil }
}

/// Pulls the destination out of a results-thread title so non-baked cities can
/// still be mapped by geocoding. Handles the common LLM title shapes:
/// "Hotels in London" and "Where to stay in London" (→ "London" via " in "),
/// plus "London Hotels" / "London Stays" (→ "London" via keyword stripping).
enum Destination {
    static func from(title: String) -> String? {
        if let entry = CityCoords.resolve(from: title) { return entry.name }
        if let r = title.range(of: " in ", options: [.backwards, .caseInsensitive]) {
            let tail = title[r.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { return tail }
        }
        return Mock.locationFromTitle(title)
    }
}

/// A live map centred on a geocoded destination with a single pin — used for
/// the hotels / cars / things-to-do pages whose city isn't in the baked
/// `CityCoords` table (e.g. "Hotels in London"). Starts pulled back over the
/// globe and eases into the resolved city so there's no hard jump.
struct PlaceMapView: View {
    let place: String
    /// Widens the framing (>1) so the composer's collapsed card can pull back.
    var zoom: CGFloat = 1

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: .init(latitude: 20, longitude: 0),
                           span: .init(latitudeDelta: 120, longitudeDelta: 120)))
    @State private var pin: CLLocationCoordinate2D?
    @State private var resolved = false

    var body: some View {
        Map(position: $camera) {
            if let pin {
                Annotation("", coordinate: pin) { marker }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .task(id: place) { await resolve() }
    }

    private func resolve() async {
        if resolved { return }
        let coord: CLLocationCoordinate2D?
        if let entry = CityCoords.resolve(from: place) {
            coord = entry.coord
        } else if let request = MKGeocodingRequest(addressString: place) {
            coord = (try? await request.mapItems)?.first?.location.coordinate
        } else {
            coord = nil
        }
        guard let coord else { return }
        pin = coord
        let span = 0.5 * zoom
        withAnimation(.easeInOut(duration: 0.7)) {
            camera = .region(MKCoordinateRegion(
                center: coord, span: .init(latitudeDelta: span, longitudeDelta: span)))
        }
        resolved = true
    }

    private var marker: some View {
        ZStack {
            Circle().fill(.white)
            Circle().strokeBorder(Theme.figmaInk.opacity(0.15), lineWidth: 1)
            EGDSIcon("mappin", size: 16)
                .foregroundStyle(Theme.figmaInk)
        }
        .frame(width: 30, height: 30)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

/// The single entry point for the results-page map. Flights and baked cities
/// keep the rich `CanvasMapView` (3D route arc / framed pin); any other
/// destination (London, Paris, …) falls back to the geocoded `PlaceMapView`, so
/// every hotels / cars / things-to-do page gets a map and the same navigation.
struct ResultsMapView: View {
    let thread: ThreadNode
    var zoom: CGFloat = 1

    static func hasMap(for thread: ThreadNode) -> Bool {
        if CanvasMapView.exists(for: thread) { return true }
        switch thread.kind {
        case .lodging, .cars, .activities, .other:
            return Destination.from(title: thread.title) != nil
        default:
            return false
        }
    }

    @ViewBuilder
    var body: some View {
        if let map = CanvasMapView.forThread(thread, zoom: zoom) {
            map
        } else if let place = Destination.from(title: thread.title) {
            PlaceMapView(place: place, zoom: zoom)
        } else {
            Color.clear
        }
    }
}
