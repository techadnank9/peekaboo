import SwiftUI

struct ContentView: View {
    @Bindable var model: PeekabooModel
    @State private var showsGallery = false

    var body: some View {
        NavigationStack {
            DuoArrangement {
                Viewfinder(model: model)
            } secondary: {
                ControlDeck(model: model)
            }
            .onFoldChange { divided, _ in
                withAnimation(.smooth) { model.isTabletop = divided }
            }
            .background(.black)
            .navigationTitle("Peekaboo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Next Attractor", systemImage: "wand.and.stars") { model.nextAttractor() }
                }
                if CameraService.isSimulated {
                    ToolbarItem(placement: .primaryAction) {
                        Button(model.demoRunning ? "Stop Demo" : "Run Demo",
                               systemImage: model.demoRunning ? "stop.circle" : "play.circle") {
                            model.toggleDemo()
                        }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Photos", systemImage: "photo.stack") { showsGallery = true }
                }
            }
            .sheet(isPresented: $showsGallery) { Gallery(shots: model.shots) }
        }
        .onAppear {
            model.camera.start()
            model.startSimulatedSubject()
            model.startCalling()
        }
        .onDisappear { model.camera.stop() }
    }
}

// MARK: - Viewfinder

private struct Viewfinder: View {
    @Bindable var model: PeekabooModel
    /// Blows the outer display mirror up for the audience.
    @State private var expanded = CameraService.isSimulated

    var body: some View {
        ZStack {
            if CameraService.isSimulated {
                SimulatedKid(yaw: model.subjectYaw, happy: model.phase != .attracting)
            } else {
                CameraPreview(camera: model.camera)
            }

            if model.faceVisible {
                LockReticle(phase: model.phase)
            }

            ShutterFlash(trigger: model.shots.count)

            if let shot = model.justCaptured {
                CaptureCard(image: shot.image)
                    .id(shot.id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 1.25).combined(with: .opacity),
                        removal: .scale(scale: 0.15, anchor: .bottomLeading).combined(with: .opacity)))
            }
        }
        .clipped()
        .overlay(alignment: .top) { statusBar }
        .overlay(alignment: .bottomTrailing) { subjectPreview }
        .subjectDisplay(isEnabled: $model.outerEnabled,
                        onAvailabilityChange: { available in model.outerAvailable = available }) {
            AttractorView(model: model)
        }
        .sensoryFeedback(.success, trigger: model.shots.count)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Label(phaseText, systemImage: phaseSymbol)
                .contentTransition(.symbolEffect(.replace))
            Spacer()
            if model.isTabletop {
                Label("Tabletop", systemImage: "laptopcomputer")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            GazeMeter(value: model.faceVisible ? model.gaze : 0)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.5), in: .capsule)
        .padding(12)
    }

    private var phaseText: String {
        switch model.phase {
        case .attracting: model.faceVisible ? "Waiting for a look" : "Find a face"
        case .locked: "Looking at the lens"
        case .celebrating: "Got it!"
        }
    }

    private var phaseSymbol: String {
        switch model.phase {
        case .attracting: "eye"
        case .locked: "scope"
        case .celebrating: "checkmark.circle.fill"
        }
    }

    /// A live miniature of the outer display, so the photographer knows what
    /// the subject is seeing. Tap to turn the outer display on or off.
    private var subjectPreview: some View {
        let scale: CGFloat = expanded ? 0.42 : 0.26
        return VStack(alignment: .trailing, spacing: 6) {
            AttractorView(model: model)
                .frame(width: 390, height: 640)
                .scaleEffect(scale, anchor: .bottomTrailing)
                .frame(width: 390 * scale, height: 640 * scale, alignment: .bottomTrailing)
                .clipShape(.rect(cornerRadius: 40 * scale + 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 40 * scale + 6)
                        .strokeBorder(.white.opacity(0.7), lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
                .opacity(model.outerEnabled ? 1 : 0.35)
                .allowsHitTesting(false)
            Text(outerLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.55), in: .capsule)
        }
        .padding(14)
        .contentShape(.rect)
        .onTapGesture { withAnimation(.spring(duration: 0.45, bounce: 0.2)) { expanded.toggle() } }
        .onLongPressGesture { withAnimation { model.outerEnabled.toggle() } }
    }

    private var outerLabel: String {
        if !model.outerEnabled { return "Outer display off" }
        return model.outerAvailable ? "Live on outer display" : "What the kid sees"
    }
}

/// Corner brackets that close in and turn green when the subject locks on.
private struct LockReticle: View {
    let phase: StagePhase

    var body: some View {
        let locked = phase != .attracting
        let size: CGFloat = locked ? 190 : 250
        ZStack {
            ForEach(0..<4) { corner in
                Bracket()
                    .stroke(locked ? Color.green : .white.opacity(0.8),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(Double(corner) * 90))
                    .offset(x: (corner == 0 || corner == 3 ? -1 : 1) * size / 2,
                            y: (corner < 2 ? -1 : 1) * size / 2)
            }
        }
        .scaleEffect(phase == .celebrating ? 1.15 : 1)
        .opacity(phase == .celebrating ? 0 : 1)
        .animation(.spring(duration: 0.35, bounce: 0.35), value: phase)
        .allowsHitTesting(false)
    }
}

/// An L-shaped corner, drawn for the top-leading corner.
private struct Bracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -rect.width / 2, y: rect.height / 2))
        p.addLine(to: CGPoint(x: -rect.width / 2, y: -rect.height / 2))
        p.addLine(to: CGPoint(x: rect.width / 2, y: -rect.height / 2))
        return p.offsetBy(dx: rect.midX, dy: rect.midY)
    }
}

private struct ShutterFlash: View {
    let trigger: Int
    @State private var opacity = 0.0

    var body: some View {
        Color.white
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: trigger) {
                opacity = 0.9
                withAnimation(.easeOut(duration: 0.45)) { opacity = 0 }
            }
    }
}

/// The fresh photo, shown like a print before it drops into the strip.
private struct CaptureCard: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 260)
            .clipped()
            .padding(10)
            .padding(.bottom, 24)
            .background(.white, in: .rect(cornerRadius: 6))
            .rotationEffect(.degrees(-4))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            .allowsHitTesting(false)
    }
}

private struct GazeMeter: View {
    let value: Double

    var body: some View {
        Gauge(value: value) { Image(systemName: "eye") }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(value > 0.8 ? .green : .yellow)
            .scaleEffect(0.55)
            .frame(width: 30, height: 30)
            .animation(.smooth, value: value)
    }
}

// MARK: - Control deck

private struct ControlDeck: View {
    @Bindable var model: PeekabooModel

    var body: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Attractor.allCases) { attractor in
                        AttractorChip(attractor: attractor, selected: model.attractor == attractor) {
                            model.select(attractor)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 28) {
                Toggle(isOn: $model.autoSnap) {
                    Label("Auto", systemImage: "eye.circle")
                }
                .toggleStyle(.button)

                Toggle(isOn: $model.soundOn) {
                    Label("Sound", systemImage: model.soundOn ? "speaker.wave.2.fill" : "speaker.slash")
                }
                .toggleStyle(.button)

                ShutterButton(phase: model.phase) { model.snap() }

                if CameraService.isSimulated {
                    Button("Glance", systemImage: "face.smiling") { model.simulateGlance() }
                        .buttonStyle(.bordered)
                } else {
                    Toggle(isOn: $model.outerEnabled) {
                        Label("Outer", systemImage: "iphone.rear.camera")
                    }
                    .toggleStyle(.button)
                }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .tint(.white)

            RecentShots(shots: model.shots)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

private struct AttractorChip: View {
    let attractor: Attractor
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(attractor.title, systemImage: attractor.symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(selected ? .black : .white)
                .background(selected ? attractor.tint : .white.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct ShutterButton: View {
    let phase: StagePhase
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                Circle()
                    .fill(phase == .locked ? .green : .white)
                    .frame(width: 64, height: 64)
                    .scaleEffect(phase == .celebrating ? 0.85 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Take photo")
        .animation(.snappy, value: phase)
    }
}

private struct RecentShots: View {
    let shots: [Shot]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if shots.isEmpty {
                    Text("Photos appear here the moment they look up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(height: 64)
                }
                ForEach(shots) { shot in
                    Image(uiImage: shot.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(.rect(cornerRadius: 12))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }
}

private struct Gallery: View {
    let shots: [Shot]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 4)], spacing: 4) {
                    ForEach(shots) { shot in
                        Image(uiImage: shot.image)
                            .resizable()
                            .scaledToFill()
                            .frame(minHeight: 150)
                            .clipped()
                    }
                }
            }
            .navigationTitle("\(shots.count) Photos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}
