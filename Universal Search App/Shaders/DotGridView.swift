import SwiftUI
import MetalKit
import simd

// MARK: - Controller (static modes + one-shot events)

/// Static geometry the grid holds.
enum DotGridMode: String, CaseIterable, Identifiable {
    case flat, globe, arrow
    var id: String { rawValue }
    var label: String {
        switch self {
        case .flat:  return "Flat"
        case .globe: return "Globe"
        case .arrow: return "Arrow"
        }
    }
}

/// Momentary, self-decaying flourishes.
enum DotGridEvent: String, CaseIterable, Identifiable {
    case pulse, shockwave, reverseShockwave, sweep, gather, burst, heartbeat, flash
    var id: String { rawValue }
    var label: String {
        switch self {
        case .reverseShockwave: return "Reverse Shockwave"
        default: return rawValue.capitalized
        }
    }
}

/// Drives a `DotGridView`: set `mode` to change the held shape, call `fire` to
/// trigger a one-shot event. Observable so SwiftUI re-syncs the mode; events are
/// forwarded imperatively to the live renderer.
@MainActor
@Observable
final class DotGridController {
    var mode: DotGridMode = .flat
    @ObservationIgnored fileprivate weak var renderer: DotGridRenderer?

    func fire(_ event: DotGridEvent) { renderer?.fire(event) }
}

// MARK: - Tunable parameters

/// The full set of dot-grid look knobs. Defaults are the current production
/// values; the playground (`DotGridPlaygroundView`) mutates a copy live and can
/// emit these as a `DotGridView(...)` call to paste back into code.
struct DotGridParams: Equatable {
    var gridCount: Int   = 50
    var pointSize: Float = 50.0541
    var amplitude: Float = 0.350078
    var speed:     Float = 0.15   // time multiplier

    var waveFreq:  Float = 1.8
    var waveFreq2: Float = 3.2
    var wave2Amp:  Float = 0.22

    var coreSharp:    Float = 120
    var coreStrength: Float = 2
    var haloSpread:   Float = 0.5
    var haloStrength: Float = 0.0875676

    var bloomMin: Float = 1.25597
    var bloomMax: Float = 2.6009
    var shadeMin: Float = 0.274054
    var shadeMax: Float = 1.58198

    var hueWarm: Float = 0.469369
    var hueCool: Float = 0.513514

    var ambientVis: Float = 0     // resting visibility (0 = grid invisible)
    var revealGain: Float = 2.5   // ripple/event reveal strength

    static let `default` = DotGridParams()
}

// MARK: - Uniforms (must match the Metal struct layout)

private struct Uniforms {
    var mvp:       float4x4
    var time:      Float
    var gridCount: Float
    var pointSize: Float
    var amplitude: Float
    var dismiss:   Float
    var morph:     Float
    var arrow:     Float
    var waveFreq:     Float
    var waveFreq2:    Float
    var wave2Amp:     Float
    var coreSharp:    Float
    var coreStrength: Float
    var haloSpread:   Float
    var haloStrength: Float
    var bloomMin:     Float
    var bloomMax:     Float
    var shadeMin:     Float
    var shadeMax:     Float
    var hueWarm:      Float
    var hueCool:      Float
    var dotColor:  SIMD4<Float>
    var bgColor:   SIMD4<Float>
    var shock:     SIMD4<Float>
    var flash:     Float
    var pulseAmp:  Float
    var sweepPos:  Float
    var sweepStr:  Float
    var gather:    Float
    var burst:     Float
    var ambientVis: Float
    var revealGain: Float
}

// MARK: - Matrix helpers

private func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let ys = 1 / tan(fovY * 0.5)
    let xs = ys / aspect
    let zs = far / (near - far)
    return float4x4(columns: (
        SIMD4(xs, 0, 0, 0),
        SIMD4(0, ys, 0, 0),
        SIMD4(0, 0, zs, -1),
        SIMD4(0, 0, zs * near, 0)
    ))
}

private func scale(_ s: Float) -> float4x4 {
    return float4x4(columns: (
        SIMD4(s, 0, 0, 0),
        SIMD4(0, s, 0, 0),
        SIMD4(0, 0, s, 0),
        SIMD4(0, 0, 0, 1)
    ))
}

private func translation(_ t: SIMD3<Float>) -> float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(t, 1)
    return m
}

private func rotationX(_ a: Float) -> float4x4 {
    let c = cos(a), s = sin(a)
    return float4x4(columns: (
        SIMD4(1, 0, 0, 0),
        SIMD4(0, c, s, 0),
        SIMD4(0, -s, c, 0),
        SIMD4(0, 0, 0, 1)
    ))
}

private func rotationY(_ a: Float) -> float4x4 {
    let c = cos(a), s = sin(a)
    return float4x4(columns: (
        SIMD4(c, 0, -s, 0),
        SIMD4(0, 1, 0, 0),
        SIMD4(s, 0, c, 0),
        SIMD4(0, 0, 0, 1)
    ))
}

// MARK: - Renderer

final class DotGridRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipeline:     MTLRenderPipelineState
    private let depthState:   MTLDepthStencilState
    private let startTime = CACurrentMediaTime()

    var gridCount: Int   = 80
    var pointSize: Float = 18
    var amplitude: Float = 0.35
    /// Full look configuration (frequencies, glow, bloom, hue). The three fields
    /// above mirror `params` for the existing call sites; `params` carries the
    /// rest and is the source of truth passed to the shader.
    var params: DotGridParams = .default
    private var aspect:  Float = 1

    // Accelerating globe spin: while the globe is formed the rotation velocity
    // ramps from a slow drift up toward a faster spin, so the globe visibly
    // picks up speed as the load state holds.
    private var spinAngle: Float = 0
    private var spinVel:    Float = 0.01         // rad/s, current angular speed
    private let spinVelBase: Float = 0.01        // idle drift (starts very slow)
    private let spinVelMax:  Float = 0.4         // ceiling while globe is up
    private let spinAccel:   Float = 0.05        // rad/s² ramp while globe up

    // Touch ripples. Released bumps decay; the active press grows while held.
    private struct Bump { var pos: SIMD2<Float>; var start: Float; var amp: Float }
    private var bumps: [Bump] = []
    private var activePos: SIMD2<Float>?
    private var activeLevel: Float = 0
    private var lastMVP = matrix_identity_float4x4
    private var lastT: Float = 0

    // Double-tap dismiss: 0 = fully visible, 1 = fully animated out. Also driven
    // externally during the loading intro to fade the grid out/in mid-morph.
    private var dismiss:       Float = 0
    var dismissTarget:         Float = 0
    private var lastTapEnd:    Float = -1
    private let dismissDur:    Float = 0.6

    // Shape morphs: 0 = off, 1 = full. Globe and arrow are mutually exclusive.
    var morphTarget: Float = 0   // globe
    var arrowTarget: Float = 0   // arrow
    private var morph: Float = 0
    private var arrow: Float = 0
    private let morphDur: Float = 1.1

    private let pressBase:    Float = 0.275  // height on first touch
    private let pressGrow:    Float = 0.65   // height gained per second held
    private let pressMax:     Float = 1.3    // ceiling for a long press
    private let releaseDecay: Float = 1.6    // settle speed after release
    private let bumpLife:     Float = 5.0

    // One-shot event start times (seconds since startTime; -1 = inactive).
    private var flashStart:     Float = -1
    private var pulseStart:     Float = -1
    private var sweepStart:     Float = -1
    private var gatherStart:    Float = -1
    private var burstStart:     Float = -1
    private var heartStart:     Float = -1
    private var shockStart:     Float = -1
    private var reverseShockStart: Float = -1
    private var shockOrigin: SIMD2<Float> = .zero

    private var nowT: Float { Float(CACurrentMediaTime() - startTime) }

    /// Trigger a momentary event. Retriggering restarts it.
    func fire(_ event: DotGridEvent) {
        let now = nowT
        switch event {
        case .pulse:     pulseStart = now
        case .flash:     flashStart = now
        case .sweep:     sweepStart = now
        case .gather:    gatherStart = now
        case .burst:     burstStart = now
        case .heartbeat: heartStart = now
        case .shockwave: shockStart = now; shockOrigin = .zero
        case .reverseShockwave: reverseShockStart = now; shockOrigin = .zero
        }
    }

    /// Unit-peak envelope: rises to 1 at age = tau, then decays smoothly.
    private func peak(_ age: Float, _ tau: Float) -> Float {
        guard age >= 0 else { return 0 }
        let x = age / tau
        return x * exp(1 - x)
    }

    /// Smooth 0→1→0 over `dur` (a half-sine). Used for gather (implode+release).
    private func sinEnv(_ age: Float, _ dur: Float) -> Float {
        guard age >= 0, age <= dur else { return 0 }
        return sin(age / dur * .pi)
    }

    // Screen point -> grid (x, z) by unprojecting onto the sheet's y = 0 plane.
    private func gridPoint(_ gr: UIGestureRecognizer, in view: UIView) -> SIMD2<Float>? {
        let p = gr.location(in: view)
        let w = Float(view.bounds.width), h = Float(view.bounds.height)
        guard w > 0, h > 0 else { return nil }
        let nx = Float(p.x) / w * 2 - 1
        let ny = 1 - Float(p.y) / h * 2

        let inv  = lastMVP.inverse
        var near = inv * SIMD4(nx, ny, 0, 1)
        var far  = inv * SIMD4(nx, ny, 1, 1)
        near /= near.w
        far  /= far.w
        let dir = far - near
        guard abs(dir.y) > 1e-5 else { return nil }
        let hit = near + (-near.y / dir.y) * dir
        return SIMD2(hit.x, hit.z)
    }

    @objc func handlePress(_ gr: UILongPressGestureRecognizer) {
        guard let view = gr.view else { return }
        switch gr.state {
        case .began:
            activeLevel = pressBase
            activePos   = gridPoint(gr, in: view)
        case .changed:
            if let hit = gridPoint(gr, in: view) { activePos = hit } // drag
        case .ended, .cancelled, .failed:
            let now = Float(CACurrentMediaTime() - startTime)
            if now - lastTapEnd < 0.3 {
                // Double tap: toggle the grid in/out.
                dismissTarget = dismissTarget > 0.5 ? 0 : 1
                lastTapEnd    = -1
            } else {
                lastTapEnd = now
                if let ap = activePos {
                    bumps.append(Bump(pos: ap, start: now, amp: activeLevel))
                    if bumps.count > 24 { bumps.removeFirst(bumps.count - 24) }
                }
            }
            activePos = nil
        default:
            break
        }
    }

    init?(mtkView: MTKView) {
        guard
            let device = mtkView.device,
            let queue  = device.makeCommandQueue(),
            let lib    = device.makeDefaultLibrary(),
            let vert   = lib.makeFunction(name: "mesh_dots_vertex"),
            let frag   = lib.makeFunction(name: "mesh_dots_fragment")
        else { return nil }

        self.commandQueue = queue

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vert
        desc.fragmentFunction = frag
        desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        desc.depthAttachmentPixelFormat       = mtkView.depthStencilPixelFormat

        // Additive blending so overlapping glows accumulate into bloom.
        let ca = desc.colorAttachments[0]!
        ca.isBlendingEnabled           = true
        ca.rgbBlendOperation           = .add
        ca.alphaBlendOperation         = .add
        ca.sourceRGBBlendFactor        = .one
        ca.sourceAlphaBlendFactor      = .one
        ca.destinationRGBBlendFactor   = .one
        ca.destinationAlphaBlendFactor = .one

        // Depth test on (so the sheet keeps its shape) but don't write depth,
        // so additive glows blend regardless of draw order.
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .lessEqual
        depthDesc.isDepthWriteEnabled  = false

        guard
            let ps = try? device.makeRenderPipelineState(descriptor: desc),
            let ds = device.makeDepthStencilState(descriptor: depthDesc)
        else { return nil }

        self.pipeline   = ps
        self.depthState = ds
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspect = size.height > 0 ? Float(size.width / size.height) : 1
    }

    func draw(in view: MTKView) {
        guard
            let rpd      = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let buf      = commandQueue.makeCommandBuffer(),
            let enc      = buf.makeRenderCommandEncoder(descriptor: rpd)
        else { return }

        let t  = Float(CACurrentMediaTime() - startTime)
        let dt = max(0, t - lastT)
        lastT  = t

        // Grow the held press toward its ceiling.
        if activePos != nil {
            activeLevel = min(pressMax, activeLevel + pressGrow * dt)
        }

        // Ease the dismiss value toward its target (double-tap toggles it).
        let step = dt / dismissDur
        if dismiss < dismissTarget { dismiss = min(dismissTarget, dismiss + step) }
        else                       { dismiss = max(dismissTarget, dismiss - step) }

        // Ease the shape weights toward their targets (buttons toggle them).
        let mStep = dt / morphDur
        if morph < morphTarget { morph = min(morphTarget, morph + mStep) }
        else                   { morph = max(morphTarget, morph - mStep) }
        if arrow < arrowTarget { arrow = min(arrowTarget, arrow + mStep) }
        else                   { arrow = max(arrowTarget, arrow - mStep) }

        // Top-down camera; sheet scaled up to overfill the screen, drifting slowly.
        // Dismiss flies the camera down into the sheet (accelerating), so dots
        // spread out and stream off-screen — the grid empties by perspective.
        // Morph tilts the camera to a 3/4 view and pulls back so the globe reads.
        let fly     = dismiss * dismiss                 // ease-in (accelerate)
        // Globe gets a 3/4 view; the arrow a gentle isometric tilt so its
        // extrusion reads as 3D.
        let pitch   = -Float.pi / 2 + morph * (Float.pi / 2 - 0.55)
                                    + arrow * (Float.pi / 2 - 1.25)
        let camDist = 3.2 - 2.95 * fly + morph * 1.0 + arrow * 0.3

        // Globe spin acceleration: while the globe is formed, ramp the angular
        // velocity toward the ceiling; when it's not, settle back to the idle
        // drift. Integrate into a persistent angle so the speed-up is smooth.
        let targetVel = spinVelBase + (spinVelMax - spinVelBase) * morph
        if spinVel < targetVel { spinVel = min(targetVel, spinVel + spinAccel * dt) }
        else                    { spinVel = max(targetVel, spinVel - spinAccel * dt) }
        spinAngle += spinVel * dt

        let model = rotationY(spinAngle) * scale(2.4)
        let view4 = translation(SIMD3(0, 0, -camDist)) * rotationX(pitch)
        let proj  = perspective(fovY: .pi / 3, aspect: aspect, near: 0.1, far: 100)
        let mvp   = proj * view4 * model
        lastMVP   = mvp

        // Build bump list as (x, z, strength, 0). Released bumps decay; the
        // active (held) press contributes its current pressure level.
        bumps.removeAll { t - $0.start > bumpLife }
        var bumpData = bumps.compactMap { b -> SIMD4<Float>? in
            let s = b.amp * exp(-(t - b.start) * releaseDecay)
            return s > 0.01 ? SIMD4(b.pos.x, b.pos.y, s, 0) : nil
        }
        if let ap = activePos {
            bumpData.append(SIMD4(ap.x, ap.y, activeLevel, 0))
        }
        if bumpData.isEmpty { bumpData.append(SIMD4(0, 0, 0, 0)) } // dummy
        var bumpCount = Int32(bumpData.contains { $0.z != 0 } ? bumpData.count : 0)

        // --- Evaluate one-shot event envelopes ---
        // Softer + slower than a snap: longer taus, gentler magnitudes.
        // Flash + pulse: unit-peak blooms.
        let flash    = flashStart >= 0 ? peak(t - flashStart, 0.34) * 0.6 : 0
        var pulseAmp = pulseStart >= 0 ? peak(t - pulseStart, 0.40) * 0.5 : 0
        // Heartbeat: two staggered pulses.
        if heartStart >= 0 {
            let age = t - heartStart
            pulseAmp += (peak(age, 0.22) + 0.7 * peak(age - 0.42, 0.22)) * 0.42
        }

        // Sweep: a band travelling across x from -1.3 to 1.3 over ~1.8s.
        let sweepDur: Float = 1.8
        var sweepPos: Float = -2
        var sweepStr: Float = 0
        if sweepStart >= 0 {
            let a = (t - sweepStart) / sweepDur
            if a <= 1 { sweepPos = -1.3 + a * 2.6; sweepStr = sin(a * .pi) * 0.7 }
        }

        // Shockwave: radius grows over ~2.5s; strength decays. Reverse shockwave
        // uses the same ring, but contracts from the outer grid toward center.
        let shockDur: Float = 2.5
        var shock = SIMD4<Float>(0, 0, 0, 0)
        if shockStart >= 0 {
            let a = (t - shockStart) / shockDur
            if a <= 1 {
                shock = SIMD4(shockOrigin.x, shockOrigin.y, a * 2.0, (1 - a) * (1 - a) * 0.6)
            }
        }
        if reverseShockStart >= 0 {
            let a = (t - reverseShockStart) / shockDur
            if a <= 1 {
                shock = SIMD4(shockOrigin.x, shockOrigin.y, (1 - a) * 2.0, sin(a * .pi) * 0.6)
            }
        }

        // Gather / burst: implode-and-release / explode envelopes.
        let gather = gatherStart >= 0 ? sinEnv(t - gatherStart, 1.5) * 0.7 : 0
        let burst  = burstStart  >= 0 ? peak(t - burstStart, 0.30) * 0.6 : 0

        var uniforms = Uniforms(
            mvp:       mvp,
            time:      t * params.speed,
            gridCount: Float(gridCount),
            pointSize: pointSize,
            amplitude: amplitude,
            dismiss:   dismiss,
            morph:     morph,
            arrow:     arrow,
            waveFreq:     params.waveFreq,
            waveFreq2:    params.waveFreq2,
            wave2Amp:     params.wave2Amp,
            coreSharp:    params.coreSharp,
            coreStrength: params.coreStrength,
            haloSpread:   params.haloSpread,
            haloStrength: params.haloStrength,
            bloomMin:     params.bloomMin,
            bloomMax:     params.bloomMax,
            shadeMin:     params.shadeMin,
            shadeMax:     params.shadeMax,
            hueWarm:      params.hueWarm,
            hueCool:      params.hueCool,
            dotColor:  SIMD4(0.20, 0.55, 1.0, 1.0),
            bgColor:   SIMD4(0.04, 0.05, 0.08, 1.0),
            shock:     shock,
            flash:     flash,
            pulseAmp:  pulseAmp,
            sweepPos:  sweepPos,
            sweepStr:  sweepStr,
            gather:    gather,
            burst:     burst,
            ambientVis: params.ambientVis,
            revealGain: params.revealGain
        )

        enc.setRenderPipelineState(pipeline)
        enc.setDepthStencilState(depthState)
        enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        enc.setVertexBytes(&bumpData, length: MemoryLayout<SIMD4<Float>>.stride * bumpData.count, index: 1)
        enc.setVertexBytes(&bumpCount, length: MemoryLayout<Int32>.stride, index: 2)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridCount * gridCount)
        enc.endEncoding()

        buf.present(drawable)
        buf.commit()
    }
}

// MARK: - SwiftUI wrapper

struct DotGridView: UIViewRepresentable {
    var params: DotGridParams = .default
    var isGlobe:   Bool  = false
    var isArrow:   Bool  = false
    /// Drives the dismiss (shrink/stream-away) fade — used by the loading intro
    /// to fade the grid out and back in mid-morph.
    var isDismissed: Bool = false
    /// Optional controller: when set, it owns the mode (overriding isGlobe/
    /// isArrow) and can fire one-shot events on the live renderer.
    var controller: DotGridController? = nil
    /// Lets event-only grid flourishes composite over existing SwiftUI layers.
    var transparent: Bool = false

    /// Full-params initializer (used by the playground).
    init(params: DotGridParams = .default,
         isGlobe: Bool = false, isArrow: Bool = false, isDismissed: Bool = false,
         controller: DotGridController? = nil, transparent: Bool = false) {
        self.params = params
        self.isGlobe = isGlobe
        self.isArrow = isArrow
        self.isDismissed = isDismissed
        self.controller = controller
        self.transparent = transparent
    }

    /// Legacy convenience initializer — overrides just the three headline knobs
    /// on top of the default look, so existing call sites keep working.
    init(gridCount: Int, pointSize: Float, amplitude: Float,
         isGlobe: Bool = false, isArrow: Bool = false, isDismissed: Bool = false,
         transparent: Bool = false) {
        var p = DotGridParams.default
        p.gridCount = gridCount
        p.pointSize = pointSize
        p.amplitude = amplitude
        self.init(params: p, isGlobe: isGlobe, isArrow: isArrow,
                  isDismissed: isDismissed, transparent: transparent)
    }

    func makeUIView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()!
        let view   = MTKView(frame: .zero, device: device)
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        applyBackground(to: view)
        view.enableSetNeedsDisplay   = false
        view.isPaused                = false
        view.preferredFramesPerSecond = 60

        if let renderer = DotGridRenderer(mtkView: view) {
            renderer.gridCount = params.gridCount
            renderer.pointSize = params.pointSize
            renderer.amplitude = params.amplitude
            renderer.params    = params
            view.delegate      = renderer
            controller?.renderer = renderer
            objc_setAssociatedObject(view, &AssocKey.renderer, renderer, .OBJC_ASSOCIATION_RETAIN)

            // Zero-duration long press fires on touch-down, tracks drags via
            // .changed, and keeps firing while held — covering tap/drag/hold.
            let press = UILongPressGestureRecognizer(target: renderer, action: #selector(DotGridRenderer.handlePress(_:)))
            press.minimumPressDuration = 0
            press.allowableMovement    = .greatestFiniteMagnitude
            view.addGestureRecognizer(press)
            view.isUserInteractionEnabled = true
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = objc_getAssociatedObject(uiView, &AssocKey.renderer) as? DotGridRenderer
        else { return }
        applyBackground(to: uiView)
        renderer.gridCount   = params.gridCount
        renderer.pointSize   = params.pointSize
        renderer.amplitude   = params.amplitude
        renderer.params      = params
        if let controller {
            controller.renderer = renderer
            renderer.morphTarget = controller.mode == .globe ? 1 : 0
            renderer.arrowTarget = controller.mode == .arrow ? 1 : 0
        } else {
            renderer.morphTarget = isGlobe ? 1 : 0
            renderer.arrowTarget = isArrow ? 1 : 0
        }
        renderer.dismissTarget = isDismissed ? 1 : 0
    }

    private func applyBackground(to view: MTKView) {
        if transparent {
            view.clearColor = MTLClearColorMake(0, 0, 0, 0)
            view.isOpaque = false
            view.backgroundColor = .clear
            view.layer.isOpaque = false
            view.layer.backgroundColor = UIColor.clear.cgColor
        } else {
            view.clearColor = MTLClearColorMake(0.02, 0.015, 0.0, 1)
            view.isOpaque = true
            view.backgroundColor = UIColor(red: 0.02, green: 0.015, blue: 0, alpha: 1)
            view.layer.isOpaque = true
        }
    }
}

private enum AssocKey {
    static var renderer = 0
}
