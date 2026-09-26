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
                ToolbarItem(placement: .secondaryAction) {
                    Button("Photos", systemImage: "photo.stack") { showsGallery = true }
                }
            }
            .sheet(isPresented: $showsGallery) { Gallery(shots: model.shots) }
        }
        .onAppear { model.camera.start() }
        .onDisappear { model.camera.stop() }
    }
}

// MARK: - Viewfinder

private struct Viewfinder: View {
    @Bindable var model: PeekabooModel

    var body: some View {
        ZStack {
            if CameraService.isSimulated {
                SimulatedSubject(attractor: model.attractor, looking: model.phase != .attracting)
                    .animation(.snappy, value: model.phase)
            } else {
                CameraPreview(camera: model.camera)
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
        .glassEffect(.regular, in: .capsule)
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
        VStack(alignment: .trailing, spacing: 6) {
            AttractorView(model: model)
                .frame(width: 390, height: 640)
                .scaleEffect(0.3, anchor: .bottomTrailing)
                .frame(width: 117, height: 192, alignment: .bottomTrailing)
                .clipShape(.rect(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.6), lineWidth: 2) }
                .opacity(model.outerEnabled ? 1 : 0.35)
                .allowsHitTesting(false)
            Text(outerLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.5), in: .capsule)
        }
        .padding(14)
        .onTapGesture { withAnimation { model.outerEnabled.toggle() } }
    }

    private var outerLabel: String {
        if !model.outerEnabled { return "Outer display off" }
        return model.outerAvailable ? "Live on outer display" : "What they'll see"
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
                            withAnimation(.bouncy) { model.attractor = attractor }
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
