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
    /// Editorial vertical adjustment for broad regional compositions.
    var labelOffsetY: CGFloat = 0
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

    private var mapIdentity: String {
        let pointKey = points.map {
            "\($0.coordinate.latitude),\($0.coordinate.longitude),\($0.label)"
        }.joined(separator: "|")
        return "\(pointKey)|\(region.center.latitude),\(region.center.longitude)|\(connect)"
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
            .id(mapIdentity)
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
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
            .offset(y: point.labelOffsetY)
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
        Entry(name: "London",           coord: .init(latitude: 51.5074, longitude: -0.1278),   span: 0.5),
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
        if let serverMap = thread.presentation.map, !serverMap.pins.isEmpty {
            let points = serverMap.pins.compactMap { pin -> MapPoint? in
                guard valid(latitude: pin.latitude, longitude: pin.longitude) else { return nil }
                return MapPoint(
                    coordinate: .init(latitude: pin.latitude, longitude: pin.longitude),
                    label: pin.label,
                    icon: "mappin",
                    showsLabel: false
                )
            }
            guard !points.isEmpty else { return destinationFallback(for: thread) }
            let automatic = CanvasMapView.autoRegion(for: points.map(\.coordinate))
            let hasValidCenter = serverMap.centerLatitude.flatMap { latitude in
                serverMap.centerLongitude.map { valid(latitude: latitude, longitude: $0) }
            } ?? false
            let center = CLLocationCoordinate2D(
                latitude: hasValidCenter ? serverMap.centerLatitude! : automatic.center.latitude,
                longitude: hasValidCenter ? serverMap.centerLongitude! : automatic.center.longitude
            )
            let delta = serverMap.zoom.map { max(0.02, 360 / pow(2, $0)) }
            return MapSpec(
                points: points,
                connect: false,
                region: MKCoordinateRegion(
                    center: center,
                    span: .init(
                        latitudeDelta: delta ?? automatic.span.latitudeDelta,
                        longitudeDelta: delta ?? automatic.span.longitudeDelta
                    )
                )
            )
        }
        return destinationFallback(for: thread)
    }

    @MainActor
    private static func destinationFallback(for thread: ThreadNode) -> MapSpec? {
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
            if thread.composition == .packageShelves {
                let coordinates = [
                    CLLocationCoordinate2D(latitude: 21.1356, longitude: -86.7520),
                    CLLocationCoordinate2D(latitude: 21.1343, longitude: -86.7442),
                    CLLocationCoordinate2D(latitude: 21.1532, longitude: -86.7921),
                ]
                let points = zip(thread.activeCards.prefix(3), coordinates).map { card, coordinate in
                    MapPoint(
                        coordinate: coordinate,
                        label: card.displayTitle,
                        icon: "mappin",
                        showsLabel: false
                    )
                }
                guard !points.isEmpty else { return nil }
                return MapSpec(
                    points: points,
                    connect: false,
                    region: MKCoordinateRegion(
                        center: .init(latitude: 21.135, longitude: -86.77),
                        span: .init(latitudeDelta: 0.32, longitudeDelta: 0.26)
                    )
                )
            }

            // The broad Mexico/package view from Figma uses a regional map with
            // the origin and representative destinations labelled in place.
            guard thread.title.localizedCaseInsensitiveContains("mexico") else { return nil }
            let points = [
                // Editorial coordinates keep every label visible above the
                // medium sheet while preserving the correct regional ordering.
                MapPoint(coordinate: .init(latitude: 28, longitude: -95.3698),
                         label: "Houston", icon: "shippingbox.fill", showsLabel: true,
                         labelOffsetY: -120),
                MapPoint(coordinate: .init(latitude: 26.5, longitude: -105.2253),
                         label: "Puerto Vallarta", icon: nil, showsLabel: true,
                         labelOffsetY: -120),
                // The broad regional frame intentionally spreads the two Yucatán
                // labels apart so both remain legible at this zoom.
                MapPoint(coordinate: .init(latitude: 26, longitude: -89),
                         label: "Cancun", icon: nil, showsLabel: true,
                         labelOffsetY: -120),
                MapPoint(coordinate: .init(latitude: 25.5, longitude: -96.5),
                         label: "Playa del Carmen", icon: nil, showsLabel: true,
                         labelOffsetY: -120),
            ]
            return MapSpec(
                points: points,
                connect: false,
                region: MKCoordinateRegion(
                    center: .init(latitude: 23, longitude: -97),
                    span: .init(latitudeDelta: 18, longitudeDelta: 27)
                )
            )

        }
    }

    private static func valid(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && !(latitude == 0 && longitude == 0)
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
        let key = "\(thread.id)|\(thread.kind)|\(thread.activeCards.first?.title ?? "")|\(thread.title)|\(String(describing: thread.presentation.map))|\(zoom)"
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
        let latitudeSpan = spec.region.span.latitudeDelta * zoom
        let longitudeSpan = spec.region.span.longitudeDelta * zoom
        return CanvasMapView(points: spec.points, connect: false,
                             regionOverride: MKCoordinateRegion(
                                center: spec.region.center,
                                span: .init(
                                    latitudeDelta: latitudeSpan,
                                    longitudeDelta: longitudeSpan
                                )))
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

/// The authored data contract for the full-map Mexico inspiration treatment.
/// Cards remain the source of display copy/prices while this adapter supplies
/// stable geography and the route metadata shown in the Figma composition.
struct MexicoVacationMapData {
    struct Destination: Identifiable {
        let card: Card
        let coordinate: CLLocationCoordinate2D
        let labelOffset: CGFloat
        let labelWidth: CGFloat
        let selected: Bool

        var id: String { card.id }

        var annotationAnchor: UnitPoint {
            let totalWidth = labelWidth + 18
            let dotCenter = labelOffset < 0 ? labelWidth + 13 : 5
            return UnitPoint(x: dotCenter / totalWidth, y: 0.5)
        }
    }

    let origin = CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698)
    let duration = "2h 31m"
    let destinations: [Destination]

    /// Default framing while the results sheet sits at its resting (sheet-up)
    /// detent: the Houston anchor pumped up and the whole region eased back so the
    /// destination pills clear the sheet.
    let region = MKCoordinateRegion(
        center: .init(latitude: 10, longitude: -93),
        span: .init(latitudeDelta: 36, longitudeDelta: 34.8)
    )

    /// Framing when the sheet is dragged down to its smallest detent, exposing far
    /// more map. Zoomed in ~20% and re-centered north so the destination pins land
    /// in the middle of the taller visible area instead of stranded at the top.
    let collapsedRegion = MKCoordinateRegion(
        center: .init(latitude: 19, longitude: -93),
        span: .init(latitudeDelta: 24, longitudeDelta: 23.2)
    )

    static func forThread(_ thread: ThreadNode) -> MexicoVacationMapData? {
        guard thread.presentation.canvasLayout == .mexicoOrientation else { return nil }
        let coordinates: [String: (CLLocationCoordinate2D, CGFloat, CGFloat)] = [
            "cancun": (.init(latitude: 21.1619, longitude: -86.8515), 48, 82),
            "puerto vallarta": (.init(latitude: 20.6534, longitude: -105.2253), 62, 136),
            "playa del carmen": (.init(latitude: 20.6296, longitude: -87.0739), -86, 158),
        ]
        let mapped = thread.activeCards.enumerated().compactMap { index, card -> Destination? in
            let key = card.displayTitle
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            guard let match = coordinates.first(where: { key.contains($0.key) })?.value else {
                return nil
            }
            return Destination(
                card: card,
                coordinate: match.0,
                labelOffset: match.1,
                labelWidth: match.2,
                selected: index == 0
            )
        }
        guard !mapped.isEmpty else { return nil }
        return MexicoVacationMapData(destinations: mapped)
    }
}

/// Full-screen regional map used by the Narrative + mock Mexico orientation.
/// It intentionally uses a flat MapKit camera: the reference is an editorial
/// overview, not the pitched route treatment used by flight-result pages.
/// One persistent map for the whole Narrative Mexico → Cancun-packages arc. It
/// renders BOTH annotation layers — the wide orientation pins (Houston origin,
/// destination name-pills, route arc) and the Cancun package price pills — in a
/// single `Map`, so the MapKit view is never torn down when the thread refines
/// from `.mexicoOrientation`/`.blocks` into `.packageShelves`. That continuity is
/// what lets the camera *fly* into Cancun and the two pin sets cross-fade instead
/// of hard-cutting. The orientation pins fade out (kept in the builder at opacity
/// 0, never removed — MapKit doesn't animate annotation insertion/removal) while
/// the package pills fade / scale / deblur in.
private struct MexicoCanvasMapView: View {
    @Bindable var store: AppStore
    let thread: ThreadNode

    @State private var camera: MapCameraPosition
    /// Last non-nil orientation snapshot. Held in state so the fade-out layer
    /// survives the refine (after which `MexicoVacationMapData.forThread` is nil).
    @State private var orientation: MexicoVacationMapData?
    /// 1 = orientation pins shown · 0 = flown to Cancun (packages).
    @State private var orientationOpacity: Double
    /// Purely-visual dark-pill selection on the package layer, local to this map.
    @State private var selectedPackageID: String?
    @State private var routeStart: CGPoint?
    @State private var routeEnd: CGPoint?
    /// 0…1 draw progress for the route arc, animated on selection so the line
    /// "launches" out of Houston toward the destination.
    @State private var routeProgress: CGFloat = 0
    /// Overall opacity of the selected route + duration chip. Held at 1 while a
    /// destination is selected and animated to 0 on deselect so the overlay
    /// fades out instead of vanishing in a single frame.
    @State private var routeOpacity: Double = 1
    /// Scale applied to the duration chip on exit so it shrinks slightly as it
    /// fades, giving the dismiss a softer, settling feel.
    @State private var chipScale: CGFloat = 1

    init(store: AppStore, thread: ThreadNode) {
        self.store = store
        self.thread = thread
        let snapshot = MexicoVacationMapData.forThread(thread)
        _orientation = State(initialValue: snapshot)
        // A thread mounted straight into packages (back-nav / deep link / seed)
        // starts framed on Cancun with the orientation layer already gone; no
        // transition. Otherwise start on the wide Mexico framing.
        if thread.composition == .packageShelves {
            let region = store.mexicoMapCollapsed
                ? CancunPackagesMapData.collapsedRegion : CancunPackagesMapData.region
            _camera = State(initialValue: .region(region))
            _orientationOpacity = State(initialValue: 0)
        } else {
            let d = snapshot ?? MexicoVacationMapData(destinations: [])
            _camera = State(initialValue: .region(store.mexicoMapCollapsed ? d.collapsedRegion : d.region))
            _orientationOpacity = State(initialValue: 1)
        }
    }

    /// Package pins are hidden through beat 1 (the fly) and stagger in at beat 1.5
    /// (`mexicoPackagePinsIn`). Outside the orchestrated transition they're simply
    /// shown (e.g. a thread opened straight into packages).
    private var pinsRevealed: Bool {
        store.mexicoPackageFly ? store.mexicoPackagePinsIn : true
    }

    /// Non-optional accessor so the orientation helpers keep reading `data.…`;
    /// falls back to an empty adapter (valid origin/region constants) when no
    /// snapshot has been captured (a package-only thread).
    private var data: MexicoVacationMapData {
        orientation ?? MexicoVacationMapData(destinations: [])
    }

    /// True once the thread is showing packages, or the fly-to-Cancun beat has
    /// begun (which leads the refine by ~0.5s).
    private var atCancun: Bool {
        thread.composition == .packageShelves || store.mexicoPackageFly
    }

    /// Package pins — non-empty only once the refine has landed.
    private var packageDestinations: [CancunPackagesMapData.Destination] {
        CancunPackagesMapData.forThread(thread)?.destinations ?? []
    }

    /// The resting region for the current sheet detent and phase, used whenever no
    /// destination is selected (an orientation selection drives its own pitched
    /// route camera).
    private var restingRegion: MKCoordinateRegion {
        guard atCancun else {
            return store.mexicoMapCollapsed ? data.collapsedRegion : data.region
        }
        // Beat 1 (still flying, sheet off-screen): a full-screen framing centring
        // the pins in the whole map. Beat 2+ (packages at the medium sheet): the
        // higher framing that lifts the pins above the sheet, or the zoomed
        // collapsed framing when the sheet is dragged to the small detent.
        if store.mexicoPackageFly { return CancunPackagesMapData.flyRegion }
        return store.mexicoMapCollapsed
            ? CancunPackagesMapData.collapsedRegion : CancunPackagesMapData.region
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                // --- Orientation layer (fades out on the fly to Cancun) ---
                Annotation("", coordinate: data.origin, anchor: .center) {
                    originMarker.opacity(orientationOpacity)
                }

                ForEach(data.destinations) { destination in
                    Annotation(
                        "",
                        coordinate: destination.coordinate,
                        anchor: destination.annotationAnchor
                    ) {
                        destinationMarker(destination).opacity(orientationOpacity)
                    }
                }

                // --- Package layer (fades / scales / deblurs in at beat 2) ---
                ForEach(Array(packageDestinations.enumerated()), id: \.element.id) { index, destination in
                    Annotation("", coordinate: destination.coordinate, anchor: .center) {
                        StaggeredPackagePill(
                            title: destination.card.displayTitle,
                            price: packagePrice(destination),
                            selected: selectedPackageID == destination.id,
                            index: index,
                            revealed: pinsRevealed
                        ) {
                            withAnimation(Theme.springSoft) {
                                selectedPackageID = selectedPackageID == destination.id ? nil : destination.id
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            // A tap on the open map (not on a pin) clears the active selection —
            // package selection in the Cancun phase, orientation selection before.
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { tap in
                        if atCancun {
                            guard selectedPackageID != nil,
                                  !hitsPackage(at: tap.location, proxy: proxy) else { return }
                            withAnimation(Theme.springSoft) { selectedPackageID = nil }
                        } else {
                            guard store.selectedMexicoDestinationID != nil,
                                  !hitsDestination(at: tap.location, proxy: proxy) else { return }
                            withAnimation(Theme.springSoft) { store.selectedMexicoDestinationID = nil }
                        }
                    }
            )
            .overlay {
                if let start = routeStart, let end = routeEnd {
                    selectedRoute(start: start, end: end)
                }
            }
            .onAppear {
                captureOrientation()
                updateRoute(proxy)
                launchRoute(active: !atCancun && store.selectedMexicoDestinationID != nil)
            }
            .onMapCameraChange(frequency: .continuous) { _ in updateRoute(proxy) }
            .onChange(of: store.selectedMexicoDestinationID) { _, id in
                // Only the orientation phase drives the pitched route camera; in
                // the Cancun phase the packages framing owns the camera.
                guard !atCancun else { return }
                orientMap(to: id)
                if id != nil {
                    routeOpacity = 1
                    chipScale = 1
                    updateRoute(proxy)
                    launchRoute(active: true)
                } else {
                    dismissRoute()
                }
            }
            // Beat 1 (fly = true): fly into the full-screen Cancun framing and fade
            // the orientation pins out. Beat 2 (fly = false): pan up to the medium
            // framing as the sheet slides in.
            .onChange(of: store.mexicoPackageFly) { _, flying in
                if flying {
                    withAnimation(Theme.mapFly) {
                        camera = .region(CancunPackagesMapData.flyRegion)
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        orientationOpacity = 0
                        routeOpacity = 0
                    }
                } else {
                    withAnimation(Theme.springMorph) {
                        camera = .region(store.mexicoMapCollapsed
                            ? CancunPackagesMapData.collapsedRegion
                            : CancunPackagesMapData.region)
                    }
                }
            }
            // A direct/cold composition change (not the orchestrated fly) settles
            // the camera and orientation opacity here; during the fly,
            // `mexicoPackageFly` owns the camera (beats 1 & 2 above).
            .onChange(of: thread.composition) { _, composition in
                captureOrientation()
                if !store.mexicoPackageFly {
                    withAnimation(Theme.springMorph) { camera = .region(restingRegion) }
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    orientationOpacity = composition == .packageShelves ? 0 : 1
                }
                updateRoute(proxy)
            }
            // A fresh card can swap in a new thread with the *same* composition
            // (e.g. the "on the beach" beachfront card is a new .packageShelves
            // search, not an in-place refine). The composition `onChange` above
            // never fires in that case, so the reused map instance keeps the
            // previous thread's drifted camera and the pins slip behind the
            // sheet. Re-seed the resting framing on any thread-identity change so
            // the pins ride high above the sheet, matching the packages view.
            .onChange(of: thread.id) { _, _ in
                captureOrientation()
                withAnimation(Theme.springMorph) { camera = .region(restingRegion) }
                withAnimation(.easeOut(duration: 0.3)) {
                    orientationOpacity = thread.composition == .packageShelves ? 0 : 1
                }
                updateRoute(proxy)
            }
            // Reframe when the sheet crosses into / out of its smallest detent,
            // but only while no destination is selected (a selection owns the
            // camera with its pitched route framing).
            .onChange(of: store.mexicoMapCollapsed) { _, _ in
                guard store.selectedMexicoDestinationID == nil else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    camera = .region(restingRegion)
                }
                updateRoute(proxy)
            }
        }
    }

    /// Keep the latest non-nil orientation snapshot so the fade-out layer still
    /// has geography after the refine (when `forThread` returns nil).
    private func captureOrientation() {
        if let latest = MexicoVacationMapData.forThread(thread) {
            orientation = latest
        }
    }

    private func packagePrice(_ destination: CancunPackagesMapData.Destination) -> String {
        destination.card.displayPrice ?? destination.card.totalPrice ?? "See price"
    }

    private func hitsPackage(at location: CGPoint, proxy: MapProxy) -> Bool {
        packageDestinations.contains { destination in
            guard let point = proxy.convert(destination.coordinate, to: .local) else {
                return false
            }
            return CGRect(x: point.x - 55, y: point.y - 26, width: 110, height: 52)
                .contains(location)
        }
    }

    private var originMarker: some View {
        Image("mexico-houston-home")
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
            .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
            .overlay {
                Text("Houston")
                    .font(.centra(size: 14, weight: .medium))
                    .foregroundStyle(Theme.figmaInk)
                    .fixedSize()
                    .offset(x: 48)
            }
    }

    private func destinationMarker(_ destination: MexicoVacationMapData.Destination) -> some View {
        HStack(spacing: 8) {
            if destination.labelOffset < 0 {
                destinationLabel(destination)
                    .frame(width: destination.labelWidth)
                destinationDot(destination)
            } else {
                destinationDot(destination)
                destinationLabel(destination)
                    .frame(width: destination.labelWidth)
            }
        }
    }

    private func destinationDot(_ destination: MexicoVacationMapData.Destination) -> some View {
        Circle()
            .fill(Theme.figmaInk)
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .onTapGesture { select(destination) }
    }

    private func destinationLabel(_ destination: MexicoVacationMapData.Destination) -> some View {
        let selected = store.selectedMexicoDestinationID == destination.id
        return Button {
            select(destination)
        } label: {
            VStack(spacing: 4) {
                Text(destination.card.displayTitle)
                    .font(.centra(size: 14))
                // Prices only ride along in the pulled-down (zoomed-in) framing;
                // the default sheet-up view keeps the pills to just the name.
                if store.mexicoMapCollapsed, let price = destination.card.displayPrice {
                    Text(price)
                        .font(.centra(size: 12))
                        .opacity(0.75)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .foregroundStyle(selected ? Color.white : Theme.figmaInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.figmaInk.opacity(0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.black, lineWidth: 1)
                        }
                } else {
                    Color.clear
                        .fauxGlass(
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show route to \(destination.card.displayTitle)")
        .fixedSize()
        // Morph the pill (height + capsule) and cross-fade the price as the sheet
        // crosses into / out of its pulled-down detent.
        .animation(.easeInOut(duration: 0.32), value: store.mexicoMapCollapsed)
    }

    private func select(_ destination: MexicoVacationMapData.Destination) {
        withAnimation(Theme.springSoft) {
            store.selectedMexicoDestinationID = destination.id
        }
    }

    private func selectedRoute(start: CGPoint, end: CGPoint) -> some View {
        let control = ArcGeometry.control(start: start, end: end, heightFactor: 0.18)
        let midpoint = ArcGeometry.point(start: start, control: control, end: end, t: 0.5)
        // The duration chip rides in over the final stretch of the launch so it
        // lands just as the arc reaches the destination.
        let chipOpacity = Double(max(0, (routeProgress - 0.7) / 0.3))
        return ZStack(alignment: .topLeading) {
            FlightArc(start: start, end: end, heightFactor: 0.18)
                .trim(from: 0, to: routeProgress)
                .stroke(
                    Theme.figmaInk,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2.5, 5])
                )

            HStack(spacing: 6) {
                EGDSIcon("flight", size: 12)
                Text(data.duration)
                    .font(.centra(size: 12))
            }
            .foregroundStyle(Theme.figmaInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .fauxGlass(in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            .scaleEffect(chipScale)
            .position(midpoint)
            .opacity(chipOpacity)

            // Re-draw the origin marker on top of the arc: the map's annotation
            // sits under this route overlay, so the line would otherwise cross
            // over the house. Pinned to the origin's projected screen point.
            originMarker
                .position(start)
        }
        .opacity(routeOpacity)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// Quickly fades the route + duration chip out (and shrinks the chip) on
    /// deselect, then clears the geometry once the animation lands so the
    /// overlay leaves smoothly instead of blinking away.
    private func dismissRoute() {
        withAnimation(.easeOut(duration: 0.22)) {
            routeOpacity = 0
            chipScale = 0.82
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            // Bail if a new destination was selected during the fade.
            guard store.selectedMexicoDestinationID == nil else { return }
            routeStart = nil
            routeEnd = nil
            routeProgress = 0
            routeOpacity = 1
            chipScale = 1
        }
    }

    /// Fires the "rocket launch" draw: snap the arc back to zero, then whip it
    /// out to the destination on the next runloop so the reset actually renders
    /// before the animation starts.
    private func launchRoute(active: Bool) {
        guard active else {
            routeProgress = 0
            return
        }
        routeProgress = 0
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.55)) {
                routeProgress = 1
            }
        }
    }

    private func updateRoute(_ proxy: MapProxy) {
        guard
            let id = store.selectedMexicoDestinationID,
            let destination = data.destinations.first(where: { $0.id == id })
        else {
            // Deselected: keep the last-known geometry so `dismissRoute` can fade
            // the overlay out. It clears the coords once the fade completes.
            return
        }
        routeStart = proxy.convert(data.origin, to: .local)
        routeEnd = proxy.convert(destination.coordinate, to: .local)
    }

    private func orientMap(to destinationID: String?) {
        guard
            let destinationID,
            let destination = data.destinations.first(where: { $0.id == destinationID })
        else {
            withAnimation(.easeInOut(duration: 0.6)) {
                camera = .region(restingRegion)
            }
            return
        }

        let destinationCoordinate = destination.coordinate
        let routeDistance = CLLocation(
            latitude: data.origin.latitude,
            longitude: data.origin.longitude
        ).distance(from: CLLocation(
            latitude: destinationCoordinate.latitude,
            longitude: destinationCoordinate.longitude
        ))
        let routeCamera = MapCamera(
            centerCoordinate: .init(
                latitude: (data.origin.latitude + destinationCoordinate.latitude) / 2,
                longitude: (data.origin.longitude + destinationCoordinate.longitude) / 2
            ),
            // A pitched camera needs substantially more altitude than a flat
            // region fit. This keeps both endpoint annotations (including the
            // selected destination/price chip) inside the usable area above the
            // carousel while retaining the maximum supported tilt.
            distance: max(2_160_000, routeDistance * 4.10),
            heading: bearing(from: destinationCoordinate, to: data.origin),
            pitch: 60
        )
        withAnimation(.easeInOut(duration: 0.75)) {
            camera = .camera(routeCamera)
        }
    }

    private func bearing(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func hitsDestination(at location: CGPoint, proxy: MapProxy) -> Bool {
        data.destinations.contains { destination in
            guard let point = proxy.convert(destination.coordinate, to: .local) else {
                return false
            }
            let dotTarget = CGRect(
                x: point.x - 22,
                y: point.y - 22,
                width: 44,
                height: 44
            )
            let labelX = destination.labelOffset < 0
                ? point.x - 13 - destination.labelWidth
                : point.x + 13
            let labelTarget = CGRect(
                x: labelX,
                y: point.y - 35,
                width: destination.labelWidth,
                height: 70
            )
            return dotTarget.contains(location) || labelTarget.contains(location)
        }
    }
}

/// A Cancun package price pill that settles in — opacity, a small scale-up, and a
/// deblur, staggered by index so the three pins land one after another as the
/// fly-in lands (mirrors `StaggeredMexicoVacationCard`). The reveal is driven by
/// the parent's `revealed` flag rather than `.onAppear`: MapKit does not reliably
/// fire `onAppear` for dynamically-added annotation content, which left the pills
/// stuck invisible. Being a pure function of its props also survives MapKit
/// recycling annotation views during the camera fly.
private struct StaggeredPackagePill: View {
    let title: String
    let price: String
    let selected: Bool
    let index: Int
    let revealed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(price)
                .font(.centra(size: 14, weight: .medium))
                .foregroundStyle(selected ? Color.white : Theme.figmaInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule()
                            .fill(Theme.figmaInk.opacity(0.92))
                            .overlay(Capsule().strokeBorder(.black, lineWidth: 1))
                    } else {
                        Color.clear.fauxGlass(in: Capsule())
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("\(title), \(price)")
        .opacity(revealed ? 1 : 0)
        .scaleEffect(revealed ? 1 : 0.8)
        .blur(radius: revealed ? 0 : 6)
        .animation(
            .spring(response: 0.46, dampingFraction: 0.84).delay(Double(index) * 0.07),
            value: revealed
        )
    }
}

/// Authored geography for the narrative Cancun packages map. The package cards
/// supply price copy; this adapter spreads them editorially along the Cancun
/// coast so the price pills stay legible at the regional zoom, and frames the
/// pins the same way the Mexico orientation does: pulled back with the cluster
/// riding high while the sheet is up, zoomed in and centred when it collapses.
struct CancunPackagesMapData {
    struct Destination: Identifiable {
        let card: Card
        let coordinate: CLLocationCoordinate2D
        var id: String { card.id }
    }

    let destinations: [Destination]

    /// Default framing (sheet at its resting detent): centred well south of the
    /// pins so the cluster rides higher — centred in the strip of map exposed above
    /// the medium sheet rather than hugging its top edge — with the pins fanned
    /// across the width so their price pills never collide. Static so the unified
    /// `MexicoCanvasMapView` can fly to it before the refine has produced any
    /// package data.
    static let region = MKCoordinateRegion(
        center: .init(latitude: 20.76, longitude: -86.78),
        span: .init(latitudeDelta: 0.62, longitudeDelta: 0.62)
    )

    /// Beat-1 framing for the card→packages fly: the sheet is still off-screen, so
    /// centre the pins in the full-screen map. Same zoom as `region`, so beat 2 is
    /// a clean vertical pan up (not a zoom) as the sheet slides to medium.
    static let flyRegion = MKCoordinateRegion(
        center: .init(latitude: 21.15, longitude: -86.78),
        span: .init(latitudeDelta: 0.62, longitudeDelta: 0.62)
    )

    /// Framing when the sheet is dragged down to its smallest detent, exposing
    /// more map: zoomed in and re-centred so the pins land in the middle of the
    /// taller visible area instead of stranded at the top.
    static let collapsedRegion = MKCoordinateRegion(
        center: .init(latitude: 21.12, longitude: -86.78),
        span: .init(latitudeDelta: 0.42, longitudeDelta: 0.42)
    )

    static func forThread(_ thread: ThreadNode) -> CancunPackagesMapData? {
        guard thread.composition == .packageShelves else { return nil }
        // Editorial coordinates fan the first three packages ACROSS the Cancun
        // coast (spread in longitude, tight in latitude) so all three price pills
        // sit side-by-side in the exposed top strip without overlapping.
        let coords: [CLLocationCoordinate2D] = [
            .init(latitude: 21.19, longitude: -86.92),
            .init(latitude: 21.15, longitude: -86.78),
            .init(latitude: 21.17, longitude: -86.64),
        ]
        let mapped = zip(thread.activeCards.prefix(3), coords).map { card, coord in
            Destination(card: card, coordinate: coord)
        }
        guard !mapped.isEmpty else { return nil }
        return CancunPackagesMapData(destinations: Array(mapped))
    }
}

/// The single entry point for the results-page map. Flights and baked cities
/// keep the rich `CanvasMapView` (3D route arc / framed pin); any other
/// destination (London, Paris, …) falls back to the geocoded `PlaceMapView`, so
/// every hotels / cars / things-to-do page gets a map and the same navigation.
struct ResultsMapView: View {
    @Bindable var store: AppStore
    let thread: ThreadNode
    var zoom: CGFloat = 1

    @ViewBuilder
    var body: some View {
        // One persistent view spans the whole Mexico orientation → Cancun packages
        // arc (the predicate is true in BOTH states) so the MapKit map is never
        // remounted across the refine — that continuity is what makes the camera
        // fly and the pins cross-fade instead of hard-cutting.
        if MexicoVacationMapData.forThread(thread) != nil
            || CancunPackagesMapData.forThread(thread) != nil {
            MexicoCanvasMapView(store: store, thread: thread)
        } else if let map = CanvasMapView.forThread(thread, zoom: zoom) {
            map
        } else if let place = Destination.from(title: thread.title) {
            PlaceMapView(place: place, zoom: zoom)
        } else {
            Color.clear
        }
    }
}
