import SwiftUI

/// Pip, an original rubber-hose cartoon puppy for the outer display. Pip runs
/// across the screen into the kid's line of sight (`lure`), bounces, wags and
/// hops continuously, and always looks toward the lens at the top center edge.
/// When the kid looks at the lens (or `locked`), Pip bounds up toward the lens
/// and does happy jump-spins.
struct PuppyCharacter: View {
    /// true when the kid is looking at the lens: the puppy gets excited.
    var locked: Bool
    /// -1...1: which side the kid is looking toward (negative = screen-left, 0 = the lens).
    var lure: Double

    @State private var excite = PupEase()
    @State private var xPos = PupEase()
    @State private var attend = PupEase()

    private var attendTarget: Double { (locked || abs(lure) < 0.15) ? 1 : 0 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)
            let u = s * 0.82
            // Keep the top 12% clear for the lens beacon.
            let cyRest = min(h * 0.56 + u * 0.03, h - u * 0.5)
            let cyLens = min(h * 0.12 + u * 0.5, cyRest)
            TimelineView(.animation) { tl in
                let now = tl.date
                let x = xPos.value(now)
                let v = xPos.velocity(now)
                let a = attend.value(now)
                let pose = PupPose(t: now.timeIntervalSinceReferenceDate,
                                   e: excite.value(now),
                                   u: u,
                                   run: min(abs(v) / 0.35, 1),
                                   dir: v >= 0 ? 1 : -1,
                                   attend: a,
                                   lookX: -x)
                PupFigure(pose: pose)
                    .frame(width: u, height: u)
                    .position(x: w / 2 + CGFloat(x * 0.35) * w,
                              y: cyRest + (cyLens - cyRest) * CGFloat(a))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            xPos = PupEase(value: lure)
            attend = PupEase(value: attendTarget)
            excite = PupEase(value: locked ? 1 : 0)
        }
        .onChange(of: locked) { _, new in
            let now = Date()
            excite.retarget(new ? 1 : 0, at: now, duration: 0.45)
            attend.retarget(attendTarget, at: now, duration: 0.7)
        }
        .onChange(of: lure) { _, new in
            let now = Date()
            if abs(new - xPos.to) > 0.04 {
                // Longer runs take longer: distance-proportional travel time.
                xPos.retarget(new, at: now, duration: 0.5 + 0.6 * abs(new - xPos.value(now)))
            }
            if attend.to != attendTarget {
                attend.retarget(attendTarget, at: now, duration: 0.7)
            }
        }
    }
}

// MARK: - Motion

private enum PupMath {
    static func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
    static func mix(_ a: Double, _ b: Double, _ k: Double) -> Double { a + (b - a) * k }
}

/// A time-based smoothstep tween that can be retargeted mid-flight without jumping.
private struct PupEase {
    var from: Double = 0
    var to: Double = 0
    var start: Date = .distantPast
    var duration: Double = 0.5

    init() {}
    init(value: Double) { from = value; to = value }

    private func progress(_ d: Date) -> Double {
        min(max(d.timeIntervalSince(start) / duration, 0), 1)
    }
    func value(_ d: Date) -> Double { from + (to - from) * PupMath.smooth(progress(d)) }
    /// Units per second.
    func velocity(_ d: Date) -> Double {
        let k = progress(d)
        return 6 * k * (1 - k) * (to - from) / duration
    }
    mutating func retarget(_ target: Double, at d: Date, duration: Double) {
        from = value(d)
        to = target
        start = d
        self.duration = duration
    }
}

/// Every animated value for one frame, derived from time alone.
private struct PupPose {
    let u: CGFloat
    let e: Double
    let run: Double
    let lookX: Double
    let wag: Double          // degrees
    let bodyY: CGFloat       // vertical offset (bounce + hop + run bob)
    let sy: CGFloat          // squash/stretch vertical scale
    let sx: CGFloat
    let lean: Double         // whole-body lean while running, degrees
    let spin: Double         // y-axis spin, degrees (tail chase, happy spin)
    let bow: Double          // 0...1 play bow
    let legSwing: Double     // degrees
    let tilt: Double         // head tilt degrees
    let ear: Double          // extra outward ear flop, degrees
    let eyeOpen: CGFloat     // blink scale
    let mouthH: CGFloat
    let pant: CGFloat

    init(t: Double, e: Double, u: CGFloat, run: Double, dir: Double, attend: Double, lookX: Double) {
        self.u = u
        self.run = run
        self.lookX = lookX
        let joy = max(e, attend * 0.6)
        self.e = e
        let mix = { (a: Double, b: Double) in PupMath.mix(a, b, joy) }
        let idleW = (1 - run) * (1 - attend)

        // Tail: fast wag, faster and wider when excited. Blend the waves, not the
        // frequencies, so switching speed never jumps phase.
        wag = (sin(t * 10) * 26) * (1 - joy) + (sin(t * 19) * 36) * joy

        // Idle bounce: |sin| gives a floor contact with a little squash on impact.
        let b = abs(sin(t * 3.0)) * (1 - joy) + abs(sin(t * 5.4)) * joy
        let bounceY = -b * 0.035 * mix(1, 1.5) * (1 - run)
        let bounceSy = 1 - 0.06 * pow(1 - b, 3) + 0.025 * b

        // Running: fast leg cycle with a bob on every stride.
        let stride = t * 16
        let slot = Int(floor(t / 3)) % 5
        let p = t.truncatingRemainder(dividingBy: 3)
        let chasing = slot == 1 && p < 1.4 ? idleW : 0
        legSwing = sin(stride) * 38 * max(run, chasing)
        let runY = -abs(sin(stride)) * 0.045 * run
        lean = dir * 9 * run

        // Idle actions in 3 s slots: hop, chase tail, hop, play bow, big jump.
        let idleHop = PupPose.hop(p: p, height: slot == 4 ? 0.15 : 0.09)
        var idleSpin = 0.0
        var idleBow = 0.0
        var idleHopUse = idleHop
        if slot == 1 {
            // Chase tail: two quick turns with the legs scampering.
            idleSpin = 720 * PupMath.smooth(min(p / 1.4, 1))
            idleHopUse = (0, 1, 0)
        } else if slot == 3 {
            // Play bow: dip down, wiggle, pop back up.
            idleBow = sin(.pi * min(p / 1.6, 1))
            idleHopUse = (0, 1, 0)
        }

        // At the lens: quick happy hops, every other one with a full spin.
        let ap = t.truncatingRemainder(dividingBy: 1.5) * 2
        let attendHop = PupPose.hop(p: ap, height: 0.1)
        let spinOn = Int(floor(t / 1.5)) % 2 == 0
        let attendSpin = spinOn ? 360 * PupMath.smooth((ap - 0.3) / 0.4) : 0

        let hopY = idleHopUse.y * idleW + attendHop.y * attend
        let hopSy = 1 + (idleHopUse.sy - 1) * idleW + (attendHop.sy - 1) * attend
        let earHop = idleHopUse.ear * idleW + attendHop.ear * attend
        spin = idleSpin * idleW + attendSpin * attend
        bow = idleBow * idleW

        let squash = hopSy * bounceSy * (1 - 0.14 * bow)
        sy = CGFloat(squash)
        sx = CGFloat(1 + (1 - squash) * 0.8)
        bodyY = CGFloat(bounceY + hopY + runY) * u

        tilt = sin(t * 0.9) * 7 + sin(t * 2.6) * 5 * joy + 10 * bow * sin(t * 6)
        ear = sin(t * 3.0 - 0.9) * mix(8, 4) + sin(t * 5.4 - 0.9) * 12 * joy + earHop
            + sin(stride - 1.2) * 16 * max(run, chasing)

        // Blink roughly every 3.7 s; happy arcs replace the eyes when excited.
        let bp = t.truncatingRemainder(dividingBy: 3.7)
        let blink = bp < 0.16 ? 1 - sin(bp / 0.16 * .pi) * 0.95 : 1
        eyeOpen = CGFloat(blink)

        pant = CGFloat(abs(sin(t * mix(6, 11)))) * 0.014 * u * CGFloat(1 + run)
        mouthH = CGFloat(mix(0.05, 0.1) + 0.02 * run) * u + pant * 0.6
    }

    /// One hop over a unit cycle `p` (seconds, from 0): anticipation squash,
    /// stretch on launch, parabolic flight, squash on landing, ear follow-through.
    static func hop(p: Double, height: Double) -> (y: Double, sy: Double, ear: Double) {
        var sy = 1.0
        if p < 0.2 {
            sy = 1 - 0.15 * PupMath.smooth(p / 0.2)
        } else if p < 0.3 {
            sy = 0.85 + 0.27 * PupMath.smooth((p - 0.2) / 0.1)
        } else if p < 0.6 {
            sy = 1.12 - 0.12 * PupMath.smooth((p - 0.3) / 0.3)
        } else if p > 0.62 && p < 0.82 {
            sy = 1 - 0.1 * sin(.pi * (p - 0.62) / 0.2)
        }
        var y = 0.0
        if p > 0.25 && p < 0.65 {
            let q = (p - 0.25) / 0.4
            y = -4 * q * (1 - q) * height
        }
        var ear = 0.0
        if p > 0.28 {
            let d = p - 0.28
            ear = -22 * sin(d * 11) * exp(-d * 3.2)
        }
        return (y, sy, ear)
    }
}

// MARK: - Drawing

private enum PupPalette {
    static let fur = Color(red: 0.99, green: 0.90, blue: 0.74)
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)
    static let tan = Color(red: 0.88, green: 0.64, blue: 0.40)
    static let ear = Color(red: 0.42, green: 0.25, blue: 0.14)
    static let ink = Color(red: 0.17, green: 0.10, blue: 0.07)
    static let tongue = Color(red: 1.0, green: 0.45, blue: 0.56)
    static let mouth = Color(red: 0.50, green: 0.10, blue: 0.16)
    static let collar = Color(red: 0.92, green: 0.22, blue: 0.28)
    static let tag = Color(red: 1.0, green: 0.80, blue: 0.22)
    static let blush = Color(red: 1.0, green: 0.55, blue: 0.60)
}

private struct PupFigure: View {
    let pose: PupPose

    var body: some View {
        let u = pose.u
        ZStack {
            tail(u)
            legs(u)
            body(u)
            PupHead(pose: pose)
                .frame(width: u, height: u)
                .rotationEffect(.degrees(pose.tilt), anchor: UnitPoint(x: 0.5, y: 0.6))
                .offset(y: (-0.08 + 0.09 * pose.bow) * u)
        }
        .frame(width: u, height: u)
        .scaleEffect(x: pose.sx, y: pose.sy, anchor: .bottom)
        .rotationEffect(.degrees(pose.lean), anchor: .bottom)
        .rotation3DEffect(.degrees(pose.spin), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .offset(y: pose.bodyY)
    }

    private var lw: CGFloat { pose.u * 0.016 }

    private func tail(_ u: CGFloat) -> some View {
        Capsule()
            .fill(PupPalette.tan)
            .stroke(PupPalette.ink, lineWidth: lw)
            .frame(width: 0.075 * u, height: 0.22 * u)
            .rotationEffect(.degrees(35 + pose.wag), anchor: .bottom)
            .offset(x: 0.17 * u, y: 0.09 * u)
    }

    private func legs(_ u: CGFloat) -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            // Hip at the top of a u-sized box; legs swing in opposite phase.
            ZStack {
                Capsule()
                    .fill(PupPalette.fur)
                    .stroke(PupPalette.ink, lineWidth: lw)
                    .frame(width: 0.1 * u, height: 0.15 * u)
                Ellipse()
                    .fill(PupPalette.cream)
                    .stroke(PupPalette.ink, lineWidth: lw)
                    .frame(width: 0.15 * u, height: 0.075 * u)
                    .offset(x: side * 0.015 * u, y: 0.065 * u)
            }
            .frame(width: 0.2 * u, height: 0.2 * u, alignment: .top)
            .rotationEffect(.degrees(side * pose.legSwing), anchor: .top)
            .offset(x: side * 0.1 * u, y: 0.405 * u)
        }
    }

    private func body(_ u: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(PupPalette.fur)
                .stroke(PupPalette.ink, lineWidth: lw)
                .frame(width: 0.44 * u, height: 0.36 * u)
                .offset(y: 0.22 * u)
            Ellipse()
                .fill(PupPalette.cream)
                .frame(width: 0.25 * u, height: 0.22 * u)
                .offset(y: 0.26 * u)
            Ellipse()
                .fill(PupPalette.tan)
                .frame(width: 0.1 * u, height: 0.08 * u)
                .offset(x: -0.14 * u, y: 0.2 * u)
            // Collar with a gold tag.
            Capsule()
                .fill(PupPalette.collar)
                .stroke(PupPalette.ink, lineWidth: lw)
                .frame(width: 0.28 * u, height: 0.045 * u)
                .offset(y: 0.08 * u)
            Circle()
                .fill(PupPalette.tag)
                .stroke(PupPalette.ink, lineWidth: lw * 0.8)
                .frame(width: 0.055 * u, height: 0.055 * u)
                .offset(y: 0.12 * u)
        }
    }
}

private struct PupHead: View {
    let pose: PupPose

    private var lw: CGFloat { pose.u * 0.016 }

    var body: some View {
        let u = pose.u
        ZStack {
            ears(u)
            Circle()
                .fill(PupPalette.fur)
                .stroke(PupPalette.ink, lineWidth: lw)
                .frame(width: 0.5 * u, height: 0.5 * u)
            // Tan patch over one eye.
            Ellipse()
                .fill(PupPalette.tan)
                .frame(width: 0.17 * u, height: 0.15 * u)
                .offset(x: 0.1 * u, y: -0.05 * u)
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(PupPalette.blush.opacity(0.45 + 0.25 * pose.e))
                    .frame(width: 0.08 * u, height: 0.045 * u)
                    .offset(x: side * 0.165 * u, y: 0.075 * u)
            }
            Ellipse()
                .fill(PupPalette.cream)
                .stroke(PupPalette.ink, lineWidth: lw * 0.7)
                .frame(width: 0.26 * u, height: 0.17 * u)
                .offset(y: 0.095 * u)
            mouth(u)
            nose(u)
            eyes(u)
        }
    }

    private func ears(_ u: CGFloat) -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            Ellipse()
                .fill(PupPalette.ear)
                .stroke(PupPalette.ink, lineWidth: lw)
                .frame(width: 0.15 * u, height: 0.3 * u)
                .rotationEffect(.degrees(-side * (20 + pose.ear)), anchor: .top)
                .offset(x: side * 0.21 * u, y: -0.04 * u)
        }
    }

    private func eyes(_ u: CGFloat) -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ZStack {
                // Open glossy eye, pupils up and inward toward the lens.
                ZStack {
                    Ellipse()
                        .fill(.white)
                        .stroke(PupPalette.ink, lineWidth: lw)
                        .frame(width: 0.13 * u, height: 0.155 * u)
                    Circle()
                        .fill(PupPalette.ink)
                        .frame(width: 0.088 * u, height: 0.088 * u)
                        .offset(x: (-side * 0.012 + 0.014 * pose.lookX) * u, y: -0.028 * u)
                    Circle()
                        .fill(.white)
                        .frame(width: 0.032 * u, height: 0.032 * u)
                        .offset(x: (-side * 0.012 + 0.014 * pose.lookX + 0.016) * u, y: -0.046 * u)
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 0.015 * u, height: 0.015 * u)
                        .offset(x: (-side * 0.012 + 0.014 * pose.lookX - 0.016) * u, y: -0.012 * u)
                }
                .scaleEffect(x: 1, y: pose.eyeOpen)
                .opacity(1 - pose.e)
                // Happy arcs when locked.
                PupArc()
                    .stroke(PupPalette.ink, style: StrokeStyle(lineWidth: 0.024 * u, lineCap: .round))
                    .frame(width: 0.11 * u, height: 0.05 * u)
                    .offset(y: -0.01 * u)
                    .opacity(pose.e)
            }
            .offset(x: side * 0.1 * u, y: -0.035 * u)
        }
    }

    private func nose(_ u: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(PupPalette.ink)
                .frame(width: 0.095 * u, height: 0.065 * u)
            Ellipse()
                .fill(.white.opacity(0.8))
                .frame(width: 0.03 * u, height: 0.016 * u)
                .offset(x: -0.015 * u, y: -0.014 * u)
        }
        .offset(y: 0.045 * u)
    }

    private func mouth(_ u: CGFloat) -> some View {
        let top = 0.105 * u
        let mh = pose.mouthH
        return ZStack {
            Capsule()
                .fill(PupPalette.ink)
                .frame(width: 0.012 * u, height: 0.04 * u)
                .offset(y: 0.085 * u)
            PupMouth()
                .fill(PupPalette.mouth)
                .stroke(PupPalette.ink, lineWidth: lw * 0.8)
                .frame(width: (0.12 + 0.03 * pose.e) * u, height: mh)
                .offset(y: top + mh / 2)
            // Panting tongue hangs out of the mouth.
            ZStack {
                Capsule()
                    .fill(PupPalette.tongue)
                    .stroke(PupPalette.ink, lineWidth: lw * 0.7)
                Capsule()
                    .fill(PupPalette.ink.opacity(0.35))
                    .frame(width: 0.006 * u)
                    .padding(.vertical, 0.015 * u)
            }
            .frame(width: 0.07 * u, height: 0.085 * u + pose.pant)
            .offset(y: top + mh * 0.75 + (0.085 * u + pose.pant) / 2 - 0.02 * u)
        }
    }
}

/// An upside-down U: the classic happy closed eye.
private struct PupArc: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        return p
    }
}

/// A flat-topped open mouth with a round bottom.
private struct PupMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        p.closeSubpath()
        return p
    }
}

#Preview {
    PuppyCharacter(locked: false, lure: 0.6)
        .background(LinearGradient(colors: [.orange, .orange.mix(with: .red, by: 0.4)],
                                   startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
}
