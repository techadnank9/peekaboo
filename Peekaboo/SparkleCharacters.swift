import SwiftUI

// MARK: - Public characters

/// Big glossy bubbles drifting up toward the lens, with a friendly bubble
/// character riding the biggest one.
struct BubblesCharacter: View {
    var locked: Bool   // true when the kid looks at the lens: celebrate more
    var lure: Double = 0   // -1...1: where the kid is looking (left/right), 0 = at the lens
    @State private var clock = SpkClock()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let s = clock.tick(t, locked: locked, lure: lure, fast: 1.9)
                Canvas { ctx, size in
                    SpkBubbles.draw(ctx, size: size, t: t, s: s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Twinkle, an ORIGINAL smiling five-point star character that bounces,
/// spins and throws sparkles.
struct TwinkleCharacter: View {
    var locked: Bool
    var lure: Double = 0   // -1...1: where the kid is looking (left/right), 0 = at the lens
    @State private var clock = SpkClock()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let s = clock.tick(t, locked: locked, lure: lure, fast: 1.45)
                let m = min(size.width, size.height)
                let pose = SpkPose.bounce(s.value)
                let up = s.up
                let scale = 1 - 0.25 * up
                let starSize = m * 0.5 * scale
                let groundX = size.width / 2 + s.lure * 0.35 * size.width
                let groundY = size.height * 0.62 - pose.height * m * 0.13 * (1 - up)
                let lensY = size.height * 0.13 + starSize * 0.62
                let ux = spkSmooth(up)
                let uy = pow(up, 0.6)
                let center = CGPoint(
                    x: groundX + (size.width / 2 - groundX) * ux,
                    y: groundY + (lensY - groundY) * uy + sin(t * 2.2) * m * 0.015 * up)
                let trail = clock.record(center, t: t)
                let squash = 1 - up
                let sx = 1 + (pose.sx - 1) * squash
                let sy = 1 + (pose.sy - 1) * squash
                let rot = pose.rot * squash + 7 * sin(t * 1.9) + s.cartwheel + 360 * spkSmooth(up)
                ZStack {
                    Canvas { ctx, sz in
                        SpkSparkles.drawRising(ctx, size: sz, from: center, t: t, lock: s.lock)
                        SpkSparkles.drawTrail(ctx, size: sz, trail: trail, t: t)
                    }
                    SpkTwinkleBody(size: starSize, t: t, lock: s.lock,
                                   wave: max(up, s.lock), air: pose.height * squash)
                        .scaleEffect(x: sx, y: sy, anchor: UnitPoint(x: 0.5, y: 0.93))
                        .rotationEffect(.degrees(rot))
                        .position(center)
                    Canvas { ctx, sz in
                        SpkSparkles.drawOrbit(ctx, size: sz, center: center, radius: starSize,
                                              t: t, lock: s.lock)
                        SpkSparkles.drawBurst(ctx, size: sz, center: center, radius: starSize * 0.45,
                                              t: t, lock: s.lock)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - Shared helpers

private struct SpkState {
    var value: Double      // eased animation clock (runs faster when locked)
    var lock: Double       // 0...1 eased locked amount
    var lure: Double       // eased lure
    var up: Double         // 0...1 eased "go to the lens" amount
    var cartwheel: Double  // degrees of the current cartwheel
}

/// A smooth clock: advances faster when locked, with every input eased so
/// nothing ever jumps. Mutated during body evaluation; it is a plain
/// reference box, so this never invalidates the view.
private final class SpkClock {
    private var last: Double?
    private var state = SpkState(value: 0, lock: 0, lure: 0, up: 0, cartwheel: 0)
    private var anchor = 0.0
    private var wheelStart = -100.0
    private var wheelDir = 0.0
    private var trail: [CGPoint] = []
    private var lastRecord = 0.0

    func tick(_ t: Double, locked: Bool, lure: Double, fast: Double) -> SpkState {
        let dt = last.map { min(max(t - $0, 0), 0.1) } ?? 0
        last = t
        let target = min(max(lure, -1), 1)
        let goUp = locked || abs(target) < 0.15
        state.lock += ((locked ? 1 : 0) - state.lock) * (1 - exp(-dt * 4))
        state.lure += (target - state.lure) * (1 - exp(-dt * 2.2))
        state.up += ((goUp ? 1 : 0) - state.up) * (1 - exp(-dt * 1.8))
        state.value += dt * (1 + (fast - 1) * state.lock)

        let wheelDur = 0.9
        if abs(target - anchor) > 0.3, t - wheelStart > wheelDur, !goUp {
            wheelDir = target > anchor ? 1 : -1
            wheelStart = t
            anchor = target
        }
        if goUp { anchor = target }
        state.cartwheel = wheelDir * 360 * spkSmooth((t - wheelStart) / wheelDur)
        if t - wheelStart >= wheelDur { state.cartwheel = 0 }
        return state
    }

    /// Keeps a short history of positions for motion trails.
    func record(_ p: CGPoint, t: Double) -> [CGPoint] {
        if t - lastRecord > 0.025 || trail.isEmpty {
            lastRecord = t
            trail.append(p)
            if trail.count > 16 { trail.removeFirst(trail.count - 16) }
        }
        return trail
    }
}

private let spkInk = Color(red: 0.13, green: 0.08, blue: 0.22)
private let spkBlush = Color(red: 1.0, green: 0.45, blue: 0.6)

private func spkFrac(_ x: Double) -> Double { x - floor(x) }
private func spkHash(_ x: Double) -> Double { spkFrac(sin(x * 12.9898 + 4.1414) * 43758.5453) }
private func spkSmooth(_ x: Double) -> Double {
    let c = min(max(x, 0), 1)
    return c * c * (3 - 2 * c)
}

/// 1 = eyes open, dips toward 0 for a quick blink every few seconds.
private func spkBlink(_ t: Double) -> Double {
    let p = spkFrac(t / 3.4)
    guard p < 0.05 else { return 1 }
    return max(0.08, 1 - sin(.pi * p / 0.05))
}

private enum SpkFace {
    /// Draws a face centered at the context origin. `r` is the face scale.
    static func draw(_ g: GraphicsContext, r: Double, t: Double, lock: Double, happyEyes: Bool) {
        let line = r * 0.045
        // Cheeks
        for s in [-1.0, 1.0] {
            let cheek = CGRect(x: s * r * 0.5 - r * 0.14, y: r * 0.14, width: r * 0.28, height: r * 0.15)
            g.fill(Path(ellipseIn: cheek), with: .color(spkBlush.opacity(0.5 + 0.3 * lock)))
        }
        // Eyes, looking up at the lens
        let blink = spkBlink(t)
        let eyeFade = happyEyes ? 1 - lock : 1
        for s in [-1.0, 1.0] {
            let ex = s * r * 0.3
            let ey = -r * 0.1
            let ew = r * 0.27
            let eh = r * 0.34 * blink
            let eyeRect = CGRect(x: ex - ew / 2, y: ey - eh / 2, width: ew, height: eh)
            let eye = Path(ellipseIn: eyeRect)
            var e = g
            e.opacity = eyeFade
            e.fill(eye, with: .color(.white))
            var inner = e
            inner.clip(to: eye)
            let pr = r * 0.12
            let px = ex + s * r * 0.015
            let py = ey - r * 0.06
            inner.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                       with: .color(spkInk))
            let hr = r * 0.045
            inner.fill(Path(ellipseIn: CGRect(x: px - pr * 0.55 - hr, y: py - pr * 0.5 - hr,
                                              width: hr * 2, height: hr * 2)), with: .color(.white))
            inner.fill(Path(ellipseIn: CGRect(x: px + pr * 0.35, y: py + pr * 0.3,
                                              width: hr, height: hr)), with: .color(.white.opacity(0.9)))
            e.stroke(eye, with: .color(spkInk), lineWidth: line)

            if happyEyes && lock > 0.01 {
                var arc = Path()
                arc.move(to: CGPoint(x: ex - ew * 0.55, y: ey + r * 0.05))
                arc.addQuadCurve(to: CGPoint(x: ex + ew * 0.55, y: ey + r * 0.05),
                                 control: CGPoint(x: ex, y: ey - r * 0.22))
                var h = g
                h.opacity = lock
                h.stroke(arc, with: .color(spkInk),
                         style: StrokeStyle(lineWidth: line * 1.7, lineCap: .round))
            }
        }
        // Mouth: a thick smile that opens into a big grin when locked
        let w = r * (0.2 + 0.1 * lock)
        let y0 = r * 0.2
        let depth = r * (0.03 + 0.24 * lock)
        var mouth = Path()
        mouth.move(to: CGPoint(x: -w, y: y0))
        mouth.addQuadCurve(to: CGPoint(x: w, y: y0), control: CGPoint(x: 0, y: y0 + r * 0.12))
        mouth.addQuadCurve(to: CGPoint(x: -w, y: y0), control: CGPoint(x: 0, y: y0 + r * 0.12 + depth * 2))
        mouth.closeSubpath()
        g.fill(mouth, with: .color(spkInk))
        if lock > 0.01 {
            var tg = g
            tg.clip(to: mouth)
            tg.opacity = lock
            let tongue = CGRect(x: -w * 0.5, y: y0 + r * 0.1 + depth * 0.7, width: w, height: depth * 1.2)
            tg.fill(Path(ellipseIn: tongue), with: .color(Color(red: 1, green: 0.4, blue: 0.45)))
        }
        g.stroke(mouth, with: .color(spkInk),
                 style: StrokeStyle(lineWidth: line * 1.3, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Bubbles

private enum SpkBubbles {
    static let rainbow = Gradient(colors: [
        Color(red: 1, green: 0.4, blue: 0.7), .orange, .yellow, .green, .cyan, .blue,
        .purple, Color(red: 1, green: 0.4, blue: 0.7),
    ])

    static func draw(_ ctx: GraphicsContext, size: CGSize, t: Double, s: SpkState) {
        let W = size.width, H = size.height, m = min(W, H)
        let c = s.value, lock = s.lock
        let side = W / 2 + s.lure * 0.35 * W
        let riseEnd = 0.88

        for i in 0..<14 {
            let fi = Double(i)
            let h1 = spkHash(fi + 0.3), h2 = spkHash(fi + 7.1), h3 = spkHash(fi + 13.7)
            let r = m * (0.05 + 0.065 * h1)
            let period = 6.0 + 4.0 * h2
            let phase = spkFrac(c / period + h3)
            let startX = W * (0.08 + 0.84 * spkFrac(fi * 0.618 + 0.13))
            let startY = H + r * 1.4
            let popY = H * (0.2 + 0.14 * h2)

            // Position along the rise at clock value cc (progress e in 0...1)
            // Bends toward the kid's side first, then curves up to the top center.
            func position(_ e: Double, _ cc: Double) -> CGPoint {
                let bend = spkSmooth(e / 0.5) * 0.6
                let toLens = pow(max(0, (e - 0.4) / 0.6), 1.5) * 0.7
                let mid = startX + (side - startX) * bend
                let drift = sin(cc * (0.6 + 0.5 * h1) + fi * 2.1) * m * 0.05 * (1 - toLens)
                let x = mid + (W / 2 - mid) * toLens + drift
                let y = startY + (popY - startY) * e
                return CGPoint(x: x, y: y)
            }

            if phase < riseEnd {
                let u = phase / riseEnd
                let e = 1 - pow(1 - u, 1.35)
                let wob = sin(t * (3 + 2 * h3) + fi) * 0.06
                bubble(ctx, center: position(e, c), r: r, sx: 1 + wob, sy: 1 - wob,
                       spin: t * 0.6 + fi, opacity: 1)
            } else {
                let p = (phase - riseEnd) / (1 - riseEnd)
                let cPop = c - p * (1 - riseEnd) * period
                pop(ctx, center: position(1, cPop), r: r, p: p)
            }
        }

        // Extra celebratory pops around the face when locked
        let fc = CGPoint(x: W / 2 + s.lure * 0.3 * W + sin(t * 0.9) * m * 0.02,
                         y: H * 0.56 + sin(t * 1.5) * m * 0.025)
        let R = m * 0.26
        if lock > 0.01 {
            var g = ctx
            g.opacity = lock
            for k in 0..<5 {
                let fk = Double(k)
                let q = spkFrac(t * 0.9 + fk / 5)
                let a = -Double.pi * (0.15 + 0.7 * spkFrac(fk * 0.618 + 0.2))
                let d = R * (1.25 + 0.25 * spkHash(fk + 3))
                let pc = CGPoint(x: fc.x + cos(a) * d, y: fc.y + sin(a) * d)
                if q < 0.55 {
                    let s = spkSmooth(q / 0.2)
                    bubble(g, center: pc, r: m * 0.045 * s, sx: 1, sy: 1, spin: t + fk, opacity: 1)
                } else {
                    pop(g, center: pc, r: m * 0.045, p: (q - 0.55) / 0.45)
                }
            }
        }

        // The big character bubble
        let w = 0.035 * sin(t * 2.3)
        bubble(ctx, center: fc, r: R, sx: 1 + w, sy: 1 - w, spin: t * 0.4, opacity: 1, outline: true)
        var f = ctx
        f.translateBy(x: fc.x, y: fc.y + R * 0.05)
        f.scaleBy(x: 1 + w, y: 1 - w)
        SpkFace.draw(f, r: R, t: t, lock: lock, happyEyes: false)
    }

    static func bubble(_ ctx: GraphicsContext, center: CGPoint, r: Double, sx: Double, sy: Double,
                       spin: Double, opacity: Double, outline: Bool = false) {
        guard r > 0.5 else { return }
        var g = ctx
        g.opacity = opacity
        g.translateBy(x: center.x, y: center.y)
        g.scaleBy(x: sx, y: sy)
        let circle = Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))

        // Translucent film body
        let body = Gradient(colors: [.white.opacity(0.05), .white.opacity(0.1), .white.opacity(0.42)])
        g.fill(circle, with: .radialGradient(body, center: .zero, startRadius: 0, endRadius: r))

        // Iridescent sheen: a rainbow band at the rim plus a faint swirl
        var sheen = g
        sheen.clip(to: circle)
        var swirl = sheen
        swirl.opacity = opacity * 0.22
        swirl.fill(circle, with: .conicGradient(rainbow, center: CGPoint(x: r * 0.2, y: r * 0.25),
                                                angle: .radians(-spin * 1.3)))
        var band = sheen
        band.opacity = opacity * 0.7
        band.addFilter(.blur(radius: r * 0.04))
        band.stroke(circle, with: .conicGradient(rainbow, center: .zero, angle: .radians(spin)),
                    lineWidth: r * 0.34)

        // Rim
        if outline {
            g.stroke(Path(ellipseIn: CGRect(x: -r - r * 0.025, y: -r - r * 0.025,
                                            width: 2 * r * 1.025, height: 2 * r * 1.025)),
                     with: .color(spkInk.opacity(0.75)), lineWidth: max(2, r * 0.03))
        }
        g.stroke(circle, with: .color(.white.opacity(0.92)), lineWidth: max(1.5, r * 0.045))

        // Specular highlights
        var h = g
        h.translateBy(x: -r * 0.42, y: -r * 0.46)
        h.rotate(by: .degrees(-40))
        h.fill(Path(ellipseIn: CGRect(x: -r * 0.24, y: -r * 0.11, width: r * 0.48, height: r * 0.22)),
               with: .color(.white.opacity(0.95)))
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.2, y: -r * 0.68, width: r * 0.1, height: r * 0.1)),
               with: .color(.white.opacity(0.85)))
        var crescent = Path()
        crescent.addArc(center: .zero, radius: r * 0.78, startAngle: .degrees(20), endAngle: .degrees(70),
                        clockwise: false)
        g.stroke(crescent, with: .color(.white.opacity(0.55)),
                 style: StrokeStyle(lineWidth: r * 0.06, lineCap: .round))
    }

    static func pop(_ ctx: GraphicsContext, center: CGPoint, r: Double, p: Double) {
        let ease = 1 - pow(1 - p, 3)
        let fade = 1 - p
        var g = ctx
        g.translateBy(x: center.x, y: center.y)

        if p < 0.3 {
            let fr = r * 0.6
            g.fill(Path(ellipseIn: CGRect(x: -fr, y: -fr, width: fr * 2, height: fr * 2)),
                   with: .color(.white.opacity(0.6 * (1 - p / 0.3))))
        }
        let rr = r * (1 + 0.6 * ease)
        let ring = Path(ellipseIn: CGRect(x: -rr, y: -rr, width: rr * 2, height: rr * 2))
        g.stroke(ring, with: .color(.white.opacity(fade)), lineWidth: max(1, r * 0.12 * fade))
        let rr2 = rr * 0.85
        var inner = g
        inner.opacity = fade * 0.8
        inner.stroke(Path(ellipseIn: CGRect(x: -rr2, y: -rr2, width: rr2 * 2, height: rr2 * 2)),
                     with: .conicGradient(rainbow, center: .zero, angle: .radians(p * 3)),
                     lineWidth: max(1, r * 0.06 * fade))

        for k in 0..<9 {
            let a = 2 * Double.pi * Double(k) / 9 + 0.3
            let d = r * (0.9 + 1.1 * ease)
            let x = cos(a) * d
            let y = sin(a) * d + r * 0.8 * p * p
            let s = r * 0.09 * (1 - p * 0.6)
            g.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                   with: .color(.white.opacity(fade)))
        }
    }
}

// MARK: - Twinkle

private struct SpkPose {
    var height = 0.0, sx = 1.0, sy = 1.0, rot = 0.0

    /// Anticipation crouch, stretched jump, squash on landing.
    static func bounce(_ c: Double) -> SpkPose {
        let p = spkFrac(c / 1.5)
        var q = 0.0, h = 0.0, rot = 0.0
        if p < 0.2 {
            q = 0.17 * sin(.pi * p / 0.2)
        } else if p < 0.88 {
            let u = (p - 0.2) / 0.68
            h = 4 * u * (1 - u)
            let edge = spkSmooth(min(u, 1 - u) / 0.1)
            q = -0.14 * pow(1 - 2 * u, 2) * edge
            rot = 10 * sin(2 * .pi * u)
        } else {
            let v = (p - 0.88) / 0.12
            q = 0.22 * sin(.pi * v)
        }
        return SpkPose(height: h, sx: 1 + q * 0.85, sy: 1 - q, rot: rot)
    }
}

private struct SpkRoundedStar: Shape {
    var innerRatio = 0.52
    var corner = 0.14

    func path(in rect: CGRect) -> Path {
        let R = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY + R * 0.08)
        let pts: [CGPoint] = (0..<10).map { i in
            let a = -Double.pi / 2 + Double(i) * .pi / 5
            let r = i.isMultiple(of: 2) ? R : R * innerRatio
            return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        }
        var p = Path()
        p.move(to: CGPoint(x: (pts[9].x + pts[0].x) / 2, y: (pts[9].y + pts[0].y) / 2))
        for i in 0..<10 {
            let rad = i.isMultiple(of: 2) ? R * corner : R * corner * 0.6
            p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % 10], radius: rad)
        }
        p.closeSubpath()
        return p
    }
}

private struct SpkTwinkleBody: View {
    let size: Double
    let t: Double
    let lock: Double
    var wave: Double = 0   // 0...1: arms up, waving
    var air: Double = 0    // 0...1: jump height, legs kick

    var body: some View {
        let star = SpkRoundedStar()
        let gold = Color(red: 1, green: 0.82, blue: 0.1)
        let orange = Color(red: 0.98, green: 0.5, blue: 0.05)
        ZStack {
            star.fill(Color(red: 1, green: 0.9, blue: 0.3))
                .scaleEffect(1.1 + 0.08 * lock)
                .blur(radius: size * 0.08)
                .opacity(0.75 + 0.25 * lock)
            star.stroke(spkInk, style: StrokeStyle(lineWidth: size * 0.075, lineJoin: .round))
            star.fill(RadialGradient(colors: [Color(red: 1, green: 0.98, blue: 0.62), gold],
                                     center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: size * 0.55))
            star.stroke(orange, style: StrokeStyle(lineWidth: size * 0.04, lineJoin: .round))
            Canvas { ctx, sz in
                let R = sz.width / 2
                // Glossy shine on the upper-left arm
                var h = ctx
                h.translateBy(x: R * 0.62, y: R * 0.62)
                h.rotate(by: .degrees(-30))
                h.fill(Path(ellipseIn: CGRect(x: -R * 0.11, y: -R * 0.05, width: R * 0.22, height: R * 0.1)),
                       with: .color(.white.opacity(0.85)))
                var f = ctx
                f.translateBy(x: R, y: R * 1.14)
                SpkFace.draw(f, r: R * 0.62, t: t, lock: lock, happyEyes: true)
            }
        }
        .frame(width: size, height: size)
        .background {
            Canvas { ctx, sz in
                SpkLimbs.draw(ctx, size: sz, starSize: size, t: t, wave: wave, air: air)
            }
            .frame(width: size * 1.6, height: size * 1.6)
        }
        .frame(width: size * 1.6, height: size * 1.6)
    }
}

/// Rubber-hose arms and legs sprouting from the star's points.
private enum SpkLimbs {
    static func draw(_ ctx: GraphicsContext, size: CGSize, starSize: Double, t: Double,
                     wave: Double, air: Double) {
        let R = starSize / 2
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + R * 0.08)
        func dir(_ deg: Double) -> CGPoint {
            CGPoint(x: cos(deg * .pi / 180), y: sin(deg * .pi / 180))
        }
        let limbColor = Color(red: 0.98, green: 0.62, blue: 0.1)

        func hose(_ from: CGPoint, _ to: CGPoint, bend: Double) {
            let mx = (from.x + to.x) / 2, my = (from.y + to.y) / 2
            let dx = to.x - from.x, dy = to.y - from.y
            let len = max(sqrt(dx * dx + dy * dy), 0.001)
            let ctrl = CGPoint(x: mx - dy / len * bend, y: my + dx / len * bend)
            var p = Path()
            p.move(to: from)
            p.addQuadCurve(to: to, control: ctrl)
            ctx.stroke(p, with: .color(spkInk), style: StrokeStyle(lineWidth: R * 0.2, lineCap: .round))
            ctx.stroke(p, with: .color(limbColor), style: StrokeStyle(lineWidth: R * 0.11, lineCap: .round))
        }

        // Legs from the two bottom points
        for (deg, side) in [(54.0, 1.0), (126.0, -1.0)] {
            let d = dir(deg)
            let hip = CGPoint(x: c.x + d.x * R * 0.72, y: c.y + d.y * R * 0.72)
            let kick = air * (0.5 + 0.5 * sin(t * 9 + side))
            let foot = CGPoint(x: hip.x + side * R * (0.1 + 0.2 * kick),
                               y: hip.y + R * (0.5 - 0.2 * kick))
            hose(hip, foot, bend: side * R * 0.08)
            var shoe = ctx
            shoe.translateBy(x: foot.x + side * R * 0.08, y: foot.y + R * 0.04)
            let rect = CGRect(x: -R * 0.17, y: -R * 0.09, width: R * 0.34, height: R * 0.18)
            shoe.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.9, green: 0.15, blue: 0.3)))
            shoe.stroke(Path(ellipseIn: rect), with: .color(spkInk), lineWidth: R * 0.05)
        }

        // Arms from the two side points: swinging, or up and waving
        for (deg, side) in [(-18.0, 1.0), (198.0, -1.0)] {
            let d = dir(deg)
            let shoulder = CGPoint(x: c.x + d.x * R * 0.72, y: c.y + d.y * R * 0.72)
            let swing = sin(t * 3 + side) * R * 0.08
            let down = CGPoint(x: shoulder.x + side * R * 0.35, y: shoulder.y + R * 0.3 + swing)
            let wig = sin(t * 12 + side * 1.3) * R * 0.14
            let upHand = CGPoint(x: shoulder.x + side * R * 0.3 + wig, y: shoulder.y - R * 0.5)
            let hand = CGPoint(x: down.x + (upHand.x - down.x) * wave,
                               y: down.y + (upHand.y - down.y) * wave)
            hose(shoulder, hand, bend: side * R * (0.12 - 0.24 * wave))
            let hr = R * 0.13
            let glove = Path(ellipseIn: CGRect(x: hand.x - hr, y: hand.y - hr, width: hr * 2, height: hr * 2))
            ctx.fill(glove, with: .color(.white))
            ctx.stroke(glove, with: .color(spkInk), lineWidth: R * 0.05)
        }
    }
}

private enum SpkSparkles {
    static let colors: [Color] = [
        .white, Color(red: 1, green: 0.95, blue: 0.5), Color(red: 1, green: 0.6, blue: 0.8),
        Color(red: 0.6, green: 0.95, blue: 1),
    ]

    static func sparkle(_ ctx: GraphicsContext, at p: CGPoint, r: Double, color: Color,
                        opacity: Double, angle: Double = 0) {
        guard r > 0.3, opacity > 0.01 else { return }
        var g = ctx
        g.opacity = opacity
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(angle))
        var path = Path()
        let k = r * 0.14
        path.move(to: CGPoint(x: 0, y: -r))
        path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: k, y: -k))
        path.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: k, y: k))
        path.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -k, y: k))
        path.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -k, y: -k))
        path.closeSubpath()
        var glow = g
        glow.addFilter(.blur(radius: r * 0.35))
        glow.fill(path, with: .color(color))
        g.fill(path, with: .color(color))
    }

    /// Sparkles streaming from Twinkle up to the lens at the top center.
    static func drawRising(_ ctx: GraphicsContext, size: CGSize, from: CGPoint, t: Double, lock: Double) {
        let m = min(size.width, size.height)
        let target = CGPoint(x: size.width / 2, y: size.height * 0.13)
        let count = 8
        for k in 0..<count {
            let fk = Double(k)
            let q = spkFrac(t * (0.32 + 0.12 * lock) + fk / Double(count))
            let e = 1 - pow(1 - q, 2)
            let sway = sin(q * 5 + fk * 1.7) * m * 0.12 * (1 - e)
            let x = from.x + (target.x - from.x) * e + sway
            let y = from.y + (target.y - from.y) * e
            let op = sin(.pi * q) * 0.85
            sparkle(ctx, at: CGPoint(x: x, y: y), r: m * (0.035 - 0.02 * q),
                    color: colors[k % colors.count], opacity: op, angle: t * 2 + fk)
        }
    }

    /// Small stars orbiting Twinkle, each with a fading trail.
    static func drawOrbit(_ ctx: GraphicsContext, size: CGSize, center: CGPoint, radius: Double,
                          t: Double, lock: Double) {
        let m = min(size.width, size.height)
        let rx = radius * 0.85, ry = radius * 0.3
        for k in 0..<5 {
            let fk = Double(k)
            let base = t * 1.4 + 2 * Double.pi * fk / 5
            for j in stride(from: 9, through: 0, by: -1) {
                let a = base - Double(j) * 0.07
                let fade = 1 - Double(j) / 10
                let p = CGPoint(x: center.x + cos(a) * rx,
                                y: center.y - m * 0.02 + sin(a) * ry - cos(a) * m * 0.05)
                let r = m * 0.03 * (j == 0 ? 1 : 0.55 * fade)
                sparkle(ctx, at: p, r: r, color: colors[k % colors.count],
                        opacity: j == 0 ? 1 : 0.55 * fade, angle: j == 0 ? t * 3 : 0)
            }
        }
    }

    /// Sparkles left behind along Twinkle's recent path, brighter the faster it moves.
    static func drawTrail(_ ctx: GraphicsContext, size: CGSize, trail: [CGPoint], t: Double) {
        guard trail.count > 1 else { return }
        let m = min(size.width, size.height)
        for i in 1..<trail.count {
            let a = trail[i - 1], b = trail[i]
            let dist = hypot(b.x - a.x, b.y - a.y)
            let speed = spkSmooth((dist - m * 0.003) / (m * 0.012))
            let age = Double(i) / Double(trail.count)
            let jitter = sin(Double(i) * 2.3 + t * 4) * m * 0.02
            sparkle(ctx, at: CGPoint(x: b.x + jitter, y: b.y + m * 0.04), r: m * 0.03 * age,
                    color: colors[i % colors.count], opacity: speed * age, angle: t * 3 + Double(i))
        }
    }

    /// Radial sparkle bursts, faded in by `lock`.
    static func drawBurst(_ ctx: GraphicsContext, size: CGSize, center: CGPoint, radius: Double,
                          t: Double, lock: Double) {
        guard lock > 0.01 else { return }
        let m = min(size.width, size.height)
        for wave in 0..<2 {
            let q = spkFrac(t * 0.8 + Double(wave) * 0.5)
            let e = 1 - pow(1 - q, 3)
            for k in 0..<12 {
                let fk = Double(k)
                let a = 2 * Double.pi * fk / 12 + Double(wave) * 0.26
                let d = radius + m * 0.38 * e
                let p = CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d)
                sparkle(ctx, at: p, r: m * 0.035 * (1 - q * 0.5),
                        color: colors[(k + wave) % colors.count], opacity: (1 - q) * lock, angle: q * 3)
            }
        }
    }
}

// MARK: - Previews

private let spkCyan = LinearGradient(colors: [.cyan, Color(red: 0.1, green: 0.4, blue: 0.9)],
                                     startPoint: .top, endPoint: .bottom)
private let spkYellow = LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)

#Preview("Bubbles on cyan") {
    ZStack { spkCyan.ignoresSafeArea(); BubblesCharacter(locked: false, lure: -0.7) }
}
#Preview("Bubbles on yellow, locked") {
    ZStack { spkYellow.ignoresSafeArea(); BubblesCharacter(locked: true) }
}
#Preview("Twinkle on cyan") {
    ZStack { spkCyan.ignoresSafeArea(); TwinkleCharacter(locked: false, lure: 0.8) }
}
#Preview("Twinkle on yellow, locked") {
    ZStack { spkYellow.ignoresSafeArea(); TwinkleCharacter(locked: true) }
}
