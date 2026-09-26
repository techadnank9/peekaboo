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
    var soundOn = true
    var outerEnabled = true
    /// Set by the system through the accessory's availability callback.
    var outerAvailable = false
    var shots: [Shot] = []
    /// The photo that just landed, shown briefly over the viewfinder.
    var justCaptured: Shot?
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
        cooldownUntil = Date().addingTimeInterval(3.2)
        camera.capturePhoto(attractor: attractor)
    }

    private func photoArrived(_ image: UIImage) {
        let shot = Shot(image: image)
        withAnimation(.snappy) {
            shots.insert(shot, at: 0)
            justCaptured = shot
            phase = .celebrating
        }
        if soundOn { Chimes.shared.celebrate() }
        PhotoSaver.save(image)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.smooth(duration: 0.5)) { justCaptured = nil }
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.smooth) { phase = .attracting }
            subjectAttention = false
            if demoRunning {
                nextAttractor()
                scheduleNextGlance(after: 2.6)
            }
        }
    }

    // MARK: Simulator subject

    /// Head turn of the simulated kid: 0 faces the lens.
    var subjectYaw: Double = 0.7
    /// Whether the attractor has caught the simulated kid's eye.
    var subjectAttention = false
    /// Runs the stage loop: look away, get caught, snap, celebrate, repeat.
    var demoRunning = false
    private var subjectTask: Task<Void, Never>?

    /// Simulator has no camera. Drive a cartoon kid through the same face
    /// pipeline Vision feeds on device, so the whole loop runs on stage.
    func startSimulatedSubject() {
        guard CameraService.isSimulated, subjectTask == nil else { return }
        subjectTask = Task { @MainActor [weak self] in
            var wander = 0.7
            var tick = 0
            while !Task.isCancelled, let self {
                tick += 1
                if tick % 14 == 0 {
                    // Toddlers look everywhere except the camera. A look to
                    // the other side is a quick head turn, not a slow sweep
                    // through the lens.
                    let side: Double = Int.random(in: 0..<4) == 0 ? -(wander.sign == .minus ? -1 : 1) : (wander.sign == .minus ? -1 : 1)
                    wander = side * Double.random(in: 0.45...0.95)
                    if !subjectAttention, (subjectYaw < 0) != (side < 0) {
                        subjectYaw = side * 0.5
                    }
                }
                let target = subjectAttention ? 0 : wander
                subjectYaw += (target - subjectYaw) * (subjectAttention ? 0.3 : 0.12)
                faceChanged(visible: true, gaze: max(0, 1 - abs(subjectYaw) / 0.45))
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    /// One glance: the attractor catches the kid's eye.
    func simulateGlance() {
        withAnimation(.smooth) { subjectAttention = true }
    }

    func toggleDemo() {
        demoRunning.toggle()
        if demoRunning { scheduleNextGlance(after: 1.5) }
    }

    private func scheduleNextGlance(after seconds: Double) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard demoRunning, phase != .celebrating else { return }
            simulateGlance()
        }
    }

    func nextAttractor() {
        let all = Attractor.allCases
        let i = all.firstIndex(of: attractor) ?? 0
        select(all[(i + 1) % all.count])
    }

    func select(_ attractor: Attractor) {
        withAnimation(.bouncy) { self.attractor = attractor }
        if soundOn { Chimes.shared.play(attractor) }
    }

    private var callTask: Task<Void, Never>?

    /// Repeats the attractor's call every few seconds while waiting for a look.
    func startCalling() {
        guard callTask == nil else { return }
        callTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard let self else { return }
                if soundOn, outerEnabled, phase == .attracting { Chimes.shared.play(attractor) }
            }
        }
    }
}
