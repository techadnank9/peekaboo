import AVFoundation

/// Tiny synthesizer for the attractor jingles. Sound turns heads faster than
/// motion, so each attractor has its own call, and a shot earns a fanfare.
final class Chimes: @unchecked Sendable {
    static let shared = Chimes()

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    /// Notes still to play: (frequency, samples remaining).
    private var queue: [(freq: Double, samples: Int)] = []
    private var phase = 0.0
    private var noteLength = 1
    private let sampleRate = 44_100.0

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let source = AVAudioSourceNode(format: format) { [unowned self] _, _, frameCount, buffers in
            let out = UnsafeMutableAudioBufferListPointer(buffers)[0]
            let samples = out.mData!.assumingMemoryBound(to: Float.self)
            lock.lock()
            defer { lock.unlock() }
            for i in 0..<Int(frameCount) {
                guard var note = queue.first else {
                    samples[i] = 0
                    continue
                }
                // A soft bell: sine plus an octave, with a fast decay.
                let t = Double(noteLength - note.samples) / sampleRate
                let envelope = note.freq == 0 ? 0 : exp(-t * 7) * min(1, t * 200)
                phase += 2 * .pi * note.freq / sampleRate
                samples[i] = Float(envelope * (0.5 * sin(phase) + 0.2 * sin(phase * 2)) * 0.6)
                note.samples -= 1
                if note.samples <= 0 {
                    queue.removeFirst()
                    noteLength = Int((queue.first?.samples) ?? 1)
                } else {
                    queue[0] = note
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    }

    func play(_ attractor: Attractor) {
        switch attractor {
        case .peekaboo: play([(659, 0.16), (784, 0.16), (1047, 0.4)])          // pee-ka-BOO
        case .bubbles: play([(880, 0.08), (0, 0.04), (1175, 0.08), (0, 0.04), (1568, 0.14)])
        case .starburst: play([(1319, 0.1), (1568, 0.1), (2093, 0.1), (2637, 0.3)])
        case .puppy: play([(523, 0.12), (0, 0.06), (523, 0.12), (0, 0.06), (784, 0.25)]) // woof woof
        }
    }

    func celebrate() {
        play([(523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.45)])
    }

    private func play(_ notes: [(Double, Double)]) {
        if !engine.isRunning { try? engine.start() }
        lock.lock()
        defer { lock.unlock() }
        let wasEmpty = queue.isEmpty
        queue += notes.map { (freq: $0.0, samples: Int($0.1 * sampleRate)) }
        if wasEmpty { noteLength = queue[0].samples }
    }
}
