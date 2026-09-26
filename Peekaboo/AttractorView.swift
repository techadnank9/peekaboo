import SwiftUI

/// The outer display: faces the same way as the camera, so everything here is
/// for the subject. It pulls their eyes toward the lens at the top edge, and
/// cheers when the shot lands. Tapping it takes the shot, so an older kid can
/// snap their own photo.
struct AttractorView: View {
    let model: PeekabooModel

    var body: some View {
        ZStack {
            background
            switch model.phase {
            case .celebrating:
                CelebrationView()
                    .transition(.scale.combined(with: .opacity))
            case .attracting, .locked:
                VStack(spacing: 0) {
                    LensBeacon(tint: model.attractor.tint, locked: model.phase == .locked)
                        .padding(.top, 14)
                    Spacer(minLength: 0)
                    attractor
                        .id(model.attractor)
                        .transition(.push(from: .trailing))
                    Spacer(minLength: 0)
                    Text(model.phase == .locked ? "Hold still!" : "Look up here!")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .padding(.bottom, 28)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { model.snap() }
        .animation(.snappy, value: model.phase)
    }

    private var background: some View {
        LinearGradient(colors: [model.attractor.tint, model.attractor.tint.mix(with: .indigo, by: 0.6)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    @ViewBuilder private var attractor: some View {
        switch model.attractor {
        case .peekaboo: PeekabooFace()
        case .bubbles: BubbleField()
        case .starburst: Starburst()
        case .puppy: WigglePuppy()
        }
    }
}

/// Arrows pulsing toward the top edge, where the camera sits above the display.
private struct LensBeacon: View {
    let tint: Color
    let locked: Bool

    var body: some View {
        PhaseAnimator([0.0, 1.0]) { t in
            VStack(spacing: -6) {
                ForEach(0..<3) { i in
                    Image(systemName: "chevron.up")
                        .font(.system(size: 26, weight: .black))
                        .opacity(locked ? 1 : 0.35 + 0.65 * (i == Int(t * 2) ? 1 : 0.3))
                }
            }
            .foregroundStyle(.white)
            .offset(y: locked ? -4 : -6 * t)
        } animation: { _ in .easeInOut(duration: 0.5) }
    }
}

private struct PeekabooFace: View {
    var body: some View {
        PhaseAnimator([false, true]) { open in
            ZStack {
                Circle().fill(.white).frame(width: 190, height: 190)
                HStack(spacing: 44) {
                    Circle().frame(width: 28, height: 28)
                    Circle().frame(width: 28, height: 28)
                }
                .offset(y: -18)
                Capsule().frame(width: open ? 70 : 40, height: open ? 44 : 14).offset(y: 42)
                HStack(spacing: open ? 170 : 8) {
                    Image(systemName: "hand.raised.fill")
                    Image(systemName: "hand.raised.fill").scaleEffect(x: -1)
                }
                .font(.system(size: 92))
                .foregroundStyle(.yellow)
                .offset(y: -10)
            }
            .foregroundStyle(.black)
        } animation: { open in open ? .spring(duration: 0.35, bounce: 0.5) : .easeIn(duration: 0.25).delay(0.9) }
    }
}

private struct BubbleField: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<14 {
                    let seed = Double(i) * 1.7
                    let speed = 40 + Double(i % 5) * 18
                    let y = size.height - (t * speed + seed * 90).truncatingRemainder(dividingBy: size.height + 80) + 40
                    let x = size.width / 2 + sin(t * 1.3 + seed) * size.width * 0.35
                    let r = 16 + Double(i % 4) * 9
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    gc.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 4)
                    gc.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.55, dy: r * 0.55).offsetBy(dx: -r * 0.3, dy: -r * 0.3)),
                            with: .color(.white.opacity(0.8)))
                }
            }
        }
    }
}

private struct Starburst: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<8) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(i.isMultiple(of: 2) ? .white : .yellow)
                        .offset(y: -80 - 20 * sin(t * 3 + Double(i)))
                        .rotationEffect(.degrees(Double(i) * 45 + t * 40))
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 90))
                    .foregroundStyle(.white)
                    .scaleEffect(1 + 0.12 * sin(t * 4))
            }
        }
    }
}

private struct WigglePuppy: View {
    var body: some View {
        PhaseAnimator([-12.0, 12.0]) { angle in
            Image(systemName: "dog.fill")
                .font(.system(size: 150))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(angle), anchor: .bottom)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.yellow)
                        .offset(x: 30, y: angle * 2 - 30)
                }
        } animation: { _ in .easeInOut(duration: 0.4) }
    }
}

private struct CelebrationView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 120))
                .symbolEffect(.bounce, options: .repeat(3))
            Text("You did it!")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
        }
        .foregroundStyle(.white)
    }
}
