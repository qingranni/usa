import SwiftUI

struct WaveGradientView: View {
    var color1: Color = Color(red: 1.0, green: 0.624, blue: 0.988)
    var color2: Color = Color(red: 0.098, green: 0.024, blue: 1.0)
    var color3: Color = Color(hex: "F3F2FF")
    var timeSpeed: Float = 5.0
    var opacity: Double = 1.0
    var scale: CGFloat = 1.25
    var solidStartColor: Color? = nil

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(startDate))
            let colors = resolvedColors(elapsed: elapsed)
            let points = resolvedPoints(elapsed: elapsed)

            MeshGradient(
                width: 3, height: 3,
                points: points,
                colors: colors
            )
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }

    // MARK: - Mesh Points

    private func resolvedPoints(elapsed: Float) -> [SIMD2<Float>] {
        guard solidStartColor != nil else {
            return meshPoints(t: elapsed * timeSpeed, chaos: 0)
        }

        let chaosPhase: Float = 0.12
        let settleEnd: Float = 0.45
        let chaos: Float
        if elapsed < chaosPhase {
            chaos = smoothstep(elapsed / chaosPhase)
        } else if elapsed < settleEnd {
            chaos = 1.0 - smoothstep((elapsed - chaosPhase) / (settleEnd - chaosPhase))
        } else {
            chaos = 0
        }

        let speedMult: Float = 1.0 + chaos * 4.0
        let t = elapsed * timeSpeed * speedMult
        return meshPoints(t: t, chaos: chaos)
    }

    private func meshPoints(t: Float, chaos: Float) -> [SIMD2<Float>] {
        let cAmp: Float = chaos * 0.15

        func jitter(_ seed: Float) -> Float {
            cAmp * sin(t * 3.2 + seed * 7.1) * cos(t * 2.7 + seed * 4.3)
        }

        return [
            .init(0.0, 0.0),
            .init(0.5 + 0.30 * sin(t * 0.35) + jitter(1), 0.0),
            .init(1.0, 0.0),

            .init(0.0, 0.5 + 0.30 * sin(t * 0.40 + 1.0) + jitter(2)),
            .init(
                0.5 + 0.12 * sin(t * 0.55) + jitter(3),
                0.5 + 0.12 * cos(t * 0.45 + 1.5) + jitter(4)
            ),
            .init(1.0, 0.5 + 0.30 * cos(t * 0.38 + 2.0) + jitter(5)),

            .init(0.0, 1.0),
            .init(0.5 + 0.30 * cos(t * 0.42 + 3.0) + jitter(6), 1.0),
            .init(1.0, 1.0),
        ]
    }

    // MARK: - Colors


    private func resolvedColors(elapsed: Float) -> [Color] {
        let finals: [Color] = [
            color1, color3, color2,
            color3, color2, color1,
            color2, color1, color3,
        ]

        guard let solid = solidStartColor else { return finals }

        let midBlue = Color(hex: "2F80ED")
        let mids: [Color] = [
            midBlue, midBlue, midBlue,
            midBlue, midBlue, midBlue,
            midBlue, midBlue, midBlue,
        ]

        let phase1End: Float = 0.06
        let phase2End: Float = 0.22
        let phase3End: Float = 0.50

        var result = [Color]()
        result.reserveCapacity(9)

        for i in 0..<9 {
            let row = i / 3
            let col = i % 3
            let pointDelay = Float(2 - row) * 0.015 + Float(col) * 0.01

            let c: Color
            if elapsed < phase1End + pointDelay {
                c = solid
            } else if elapsed < phase2End + pointDelay {
                let p = smoothstep((elapsed - phase1End - pointDelay) / (phase2End - phase1End))
                c = lerp(from: solid, to: mids[i], t: p)
            } else if elapsed < phase3End + pointDelay {
                let p = smoothstep((elapsed - phase2End - pointDelay) / (phase3End - phase2End))
                c = lerp(from: mids[i], to: finals[i], t: p)
            } else {
                c = finals[i]
            }
            result.append(c)
        }

        return result
    }

    // MARK: - Helpers

    private func smoothstep(_ x: Float) -> Float {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func lerp(from a: Color, to b: Color, t p: Float) -> Color {
        let ae = UIColor(a)
        let be = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ae.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        be.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let cp = CGFloat(p)
        return Color(
            red: Double(ar + (br - ar) * cp),
            green: Double(ag + (bg - ag) * cp),
            blue: Double(ab + (bb - ab) * cp)
        )
    }
}
