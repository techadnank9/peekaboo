import SwiftUI
import Observation

/// What the subject sees on the outer display.
enum Attractor: String, CaseIterable, Identifiable {
    case peekaboo, bubbles, starburst, puppy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .peekaboo: "Peekaboo"
        case .bubbles: "Bubbles"
        case .starburst: "Sparkles"
        case .puppy: "Puppy"
        }
    }

    var symbol: String {
        switch self {
        case .peekaboo: "face.smiling"
        case .bubbles: "bubbles.and.sparkles"
        case .starburst: "sparkles"
        case .puppy: "dog"
        }
    }

    var tint: Color {
        switch self {
        case .peekaboo: .orange
        case .bubbles: .cyan
        case .starburst: .yellow
        case .puppy: .pink
        }
    }
}

enum StagePhase: Equatable {
    /// Playing the attractor, waiting for the subject to look at the lens.
    case attracting
    /// The subject is looking at the lens; the shot is about to fire.
    case locked
    /// A photo was just taken; the outer display rewards the subject.
    case celebrating
}

struct Shot: Identifiable {
    let id = UUID()
    let image: UIImage
    let date = Date()
}

/// State shared by the capture interface on the inner display and the
/// accessory content on the outer display. Both sides read the same object,
/// so a tap on the outer display changes what the photographer sees.
@Observable
final class PeekabooModel {
    var attractor: Attractor = .peekaboo
    var phase: StagePhase = .attracting
    var autoSnap = true
    var outerEnabled = true
    /// Set by the system through the accessory's availability callback.
    var outerAvailable = false
    var shots: [Shot] = []
    /// How squarely the subject faces the lens, 0...1, from Vision.
    var gaze: Double = 0
    var faceVisible = false
    /// Whether the fold currently divides the view (tabletop pose).
    var isTabletop = false

    let camera = CameraService()

    private var lockedSince: Date?
    private var cooldownUntil = Date.distantPast

    init() {
        camera.onFace = { [weak self] visible, gaze in
            Task { @MainActor in self?.faceChanged(visible: visible, gaze: gaze) }
        }
        camera.onPhoto = { [weak self] image in
            Task { @MainActor in self?.photoArrived(image) }
        }
    }

    func faceChanged(visible: Bool, gaze: Double) {
        faceVisible = visible
        self.gaze = gaze
        guard phase != .celebrating, Date() >= cooldownUntil else { return }

        let looking = visible && gaze > 0.8
        if looking {
            if lockedSince == nil { lockedSince = Date() }
            phase = .locked
            if autoSnap, let since = lockedSince, Date().timeIntervalSince(since) > 0.2 {
                snap()
            }
        } else {
            lockedSince = nil
            phase = .attracting
        }
    }

    func snap() {
        lockedSince = nil
        cooldownUntil = Date().addingTimeInterval(2.5)
        camera.capturePhoto(attractor: attractor)
    }

    private func photoArrived(_ image: UIImage) {
        withAnimation(.snappy) {
            shots.insert(Shot(image: image), at: 0)
            phase = .celebrating
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.smooth) { phase = .attracting }
        }
    }

    /// Simulator has no camera: play the same glance the Vision pipeline
    /// would report, so the whole loop runs on stage.
    func simulateGlance() {
        Task { @MainActor in
            for step in 0..<5 {
                faceChanged(visible: true, gaze: 0.5 + Double(step) * 0.12)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    func nextAttractor() {
        let all = Attractor.allCases
        let i = all.firstIndex(of: attractor) ?? 0
        withAnimation(.bouncy) { attractor = all[(i + 1) % all.count] }
    }
}
