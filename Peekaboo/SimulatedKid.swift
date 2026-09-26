import SwiftUI

/// A cartoon toddler standing in for the live camera in Simulator. `yaw` turns
/// the head: 0 faces the lens, ±1 looks fully to the side. The demo director
/// drives it through the same face pipeline Vision uses on device.
struct SimulatedKid: View {
    var yaw: Double
    var happy: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Room()
                Head(yaw: yaw, happy: happy)
                    .frame(width: side * 0.52, height: side * 0.52)
                    .offset(y: side * 0.04)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }
}

private struct Room: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.98, green: 0.86, blue: 0.72), Color(red: 0.93, green: 0.72, blue: 0.62)],
                           startPoint: .top, endPoint: .bottom)
            // Window light and a sofa, softly out of focus like a real background.
            RoundedRectangle(cornerRadius: 30)
                .fill(.white.opacity(0.55))
                .frame(width: 220, height: 260)
                .offset(x: -150, y: -220)
                .blur(radius: 18)
            Capsule()
                .fill(Color(red: 0.36, green: 0.55, blue: 0.66))
                .frame(height: 220)
                .padding(.horizontal, -60)
                .offset(y: 90)
                .blur(radius: 10)
        }
    }
}

private struct Head: View {
    var yaw: Double
    var happy: Bool

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            let turn = CGFloat(yaw)
            ZStack {
                // Ears sit behind the face and slide opposite the turn.
                HStack(spacing: s * 0.78) {
                    ear(s).opacity(turn > 0.5 ? 0.4 : 1)
                    ear(s).opacity(turn < -0.5 ? 0.4 : 1)
                }
                .offset(x: -turn * s * 0.08)

                Circle()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.68))
                    .overlay(alignment: .top) {
                        // A tuft of hair.
                        Image(systemName: "scribble")
                            .font(.system(size: s * 0.22, weight: .heavy))
                            .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.16))
                            .offset(x: turn * s * 0.1, y: -s * 0.08)
                    }
                    .scaleEffect(x: 1 - abs(turn) * 0.08)

                // Features slide across the face as the head turns.
                VStack(spacing: s * 0.07) {
                    HStack(spacing: s * 0.2) {
                        eye(s, turn: turn)
                        eye(s, turn: turn)
                    }
                    ZStack {
                        HStack(spacing: s * 0.36) {
                            Circle().fill(.pink.opacity(0.45)).frame(width: s * 0.13)
                            Circle().fill(.pink.opacity(0.45)).frame(width: s * 0.13)
                        }
                        mouth(s)
                    }
                    .frame(height: s * 0.16)
                }
                .offset(x: turn * s * 0.26, y: s * 0.05)
            }
        }
    }

    private func ear(_ s: CGFloat) -> some View {
        Circle().fill(Color(red: 0.98, green: 0.76, blue: 0.62)).frame(width: s * 0.2)
    }

    private func eye(_ s: CGFloat, turn: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(.white).frame(width: s * 0.15, height: s * 0.17)
            Circle()
                .fill(Color(red: 0.2, green: 0.14, blue: 0.1))
                .frame(width: s * 0.09)
                .overlay(alignment: .topLeading) {
                    Circle().fill(.white).frame(width: s * 0.03).offset(x: s * 0.01, y: s * 0.01)
                }
                .offset(x: turn * s * 0.035)
        }
        .scaleEffect(y: happy ? 0.85 : 1)
    }

    @ViewBuilder private func mouth(_ s: CGFloat) -> some View {
        if happy {
            // Open grin.
            Circle()
                .trim(from: 0.05, to: 0.45)
                .fill(Color(red: 0.62, green: 0.16, blue: 0.2))
                .frame(width: s * 0.22)
                .offset(y: -s * 0.05)
        } else {
            Capsule()
                .fill(Color(red: 0.62, green: 0.16, blue: 0.2))
                .frame(width: s * 0.07, height: s * 0.05)
        }
    }
}

#Preview("Looking away") { SimulatedKid(yaw: 0.8, happy: false) }
#Preview("At the lens") { SimulatedKid(yaw: 0, happy: true) }

/// A photo-real toddler for stage demos, made with Decart from the cartoon
/// kid: one shot looking left, one right, one smiling into the lens. The
/// head turn crossfades between them as `yaw` changes.
struct RealisticKid: View {
    var yaw: Double

    static let center = UIImage(named: "kid-center.jpg")
    static let left = UIImage(named: "kid-left.jpg")
    static let right = UIImage(named: "kid-right.jpg")
    static var isAvailable: Bool { center != nil && left != nil && right != nil }

    var body: some View {
        // SimulatedKid's positive yaw turns the face to screen-right.
        let toRight = max(0, min(1, (yaw - 0.12) / 0.3))
        let toLeft = max(0, min(1, (-yaw - 0.12) / 0.3))
        let atLens = max(0, 1 - toRight - toLeft)
        TimelineView(.animation) { context in
            let breathe = 1 + 0.008 * sin(context.date.timeIntervalSinceReferenceDate * 1.6)
            ZStack {
                layer(Self.left, opacity: toLeft)
                layer(Self.right, opacity: toRight)
                layer(Self.center, opacity: atLens)
            }
            .scaleEffect(breathe)
        }
        .clipped()
    }

    private func layer(_ image: UIImage?, opacity: Double) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .opacity(opacity)
    }
}
