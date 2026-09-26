import Lottie
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
                CelebrationView(photo: model.shots.first?.image)
                    .transition(.scale.combined(with: .opacity))
            case .attracting, .locked:
                attractor
                    .id(model.attractor)
                    .transition(.push(from: .trailing))
                VStack(spacing: 0) {
                    LensBeacon(tint: model.attractor.tint, locked: model.phase == .locked)
                        .padding(.top, 14)
                    Spacer(minLength: 0)
                    Text(model.phase == .locked ? "Hold still!" : "Look up here!")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
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

    /// Every character goes where the kid is looking, then leads them up to
    /// the lens.
    @ViewBuilder private var attractor: some View {
        let locked = model.phase == .locked
        switch model.attractor {
        case .puppy:
            PuppyCharacter(locked: locked, lure: model.lure)
        case .bubbles:
            BubblesCharacter(locked: locked, lure: model.lure)
        case .twinkle:
            TwinkleCharacter(locked: locked, lure: model.lure)
        default:
            LureStage(lure: model.lure, locked: locked) {
                LottieCharacter(name: model.attractor.animationName ?? "")
            }
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

/// Confetti bursting from the top edge, where the lens is.
private struct Confetti: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSince(start)
                let colors: [Color] = [.yellow, .white, .pink, .mint, .orange, .cyan]
                for i in 0..<70 {
                    let seed = Double(i) * 12.9898
                    let angle = (sin(seed) * 0.5 + 0.5) * .pi * 0.8 + .pi * 0.1
                    let speed = 260 + (cos(seed * 1.7) * 0.5 + 0.5) * 380
                    let x = size.width / 2 + cos(angle) * speed * t * (i.isMultiple(of: 2) ? 1 : -1)
                    let y = 20 + sin(angle) * speed * t + 420 * t * t
                    guard y < size.height + 20 else { continue }
                    var piece = gc
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(t * 8 + seed))
                    piece.fill(Path(CGRect(x: -5, y: -3, width: 10, height: 6)),
                               with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The reward: the kid sees the photo they just starred in. The loop runs
/// both ways, from the photographer to the kid and back.
private struct CelebrationView: View {
    let photo: UIImage?
    @State private var landed = false

    var body: some View {
        ZStack {
            Confetti()
            VStack(spacing: 18) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 210, height: 260)
                        .clipped()
                        .padding(8)
                        .padding(.bottom, 22)
                        .background(.white, in: .rect(cornerRadius: 6))
                        .rotationEffect(.degrees(landed ? -5 : 12))
                        .scaleEffect(landed ? 1 : 0.4)
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                } else {
                    Image(systemName: "hands.and.sparkles.fill")
                        .font(.system(size: 120))
                        .symbolEffect(.bounce, options: .repeat(3))
                }
                Text(photo == nil ? "You did it!" : "That's you!")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.45)) { landed = true }
        }
    }
}

/// A professionally animated character, played full screen and looped.
struct LottieCharacter: View {
    let name: String

    var body: some View {
        LottieView(animation: .named(name))
            .playing(loopMode: .loop)
            .resizable()
            .scaledToFit()
    }
}

/// Moves a whole character around the outer display: it hops over to the
/// side the kid is looking at, then bounds up toward the lens at the top.
struct LureStage<Content: View>: View {
    var lure: Double
    var locked: Bool
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let atLens = locked || abs(lure) < 0.15
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let speed = locked ? 7.0 : 4.0
                let bounce = abs(sin(t * speed))
                content
                    .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.6)
                    // Squash at the bottom of each hop, stretch at the top.
                    .scaleEffect(x: 1 + 0.05 * (1 - bounce), y: 1 - 0.05 * (1 - bounce), anchor: .bottom)
                    .offset(y: -bounce * geo.size.height * (locked ? 0.06 : 0.035))
                    .rotationEffect(.degrees(atLens ? sin(t * 2) * 4 : lure * 10))
            }
            .offset(x: atLens ? 0 : lure * geo.size.width * 0.28,
                    y: atLens ? -geo.size.height * 0.08 : geo.size.height * 0.1)
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(duration: 0.9, bounce: 0.35), value: lure)
            .animation(.spring(duration: 0.6, bounce: 0.45), value: locked)
        }
    }
}
