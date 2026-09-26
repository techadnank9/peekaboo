import AVFoundation
import SwiftUI
import Vision

/// Owns the capture session. Runs a photo output for shots and a video data
/// output that feeds Vision, which reports whether the subject faces the lens.
final class CameraService: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    var onFace: ((Bool, Double, Double) -> Void)?
    var onPhoto: ((UIImage) -> Void)?

    private let queue = DispatchQueue(label: "peekaboo.capture")
    private let visionQueue = DispatchQueue(label: "peekaboo.vision")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput?
    private var lastVision = Date.distantPast

    static var isSimulated: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        AVCaptureDevice.default(for: .video) == nil
        #endif
    }

    func start() {
        guard !Self.isSimulated else { return }
        queue.async { [self] in
            guard session.inputs.isEmpty else {
                if !session.isRunning { session.startRunning() }
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .photo
            // Start on the main rear camera: it faces the subject while the
            // photographer holds the device open. The direction coordinator
            // corrects this when the device changes pose.
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
                self.input = input
            }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in session.stopRunning() }
    }

    /// Swaps the single video input for the camera with this unique ID.
    func selectCamera(uniqueID: String) {
        queue.async { [self] in
            guard input?.device.uniqueID != uniqueID,
                  let device = AVCaptureDevice(uniqueID: uniqueID),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            if let input { session.removeInput(input) }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
            } else if let input {
                session.addInput(input)
            }
        }
    }

    func capturePhoto(attractor: Attractor) {
        if Self.isSimulated {
            Task { @MainActor in
                if let photo = RealisticKid.center {
                    onPhoto?(photo)
                    return
                }
                let renderer = ImageRenderer(content: SimulatedKid(yaw: 0, happy: true)
                    .frame(width: 600, height: 800))
                renderer.scale = 2
                if let image = renderer.uiImage { onPhoto?(image) }
            }
            return
        }
        queue.async { [self] in
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        onPhoto?(image)
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Vision at ~10 fps is plenty to catch a glance.
        guard Date().timeIntervalSince(lastVision) > 0.1,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastVision = Date()

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        try? VNImageRequestHandler(cvPixelBuffer: pixels, options: [:]).perform([request])

        guard let face = request.results?.max(by: { $0.boundingBox.area < $1.boundingBox.area }) else {
            onFace?(false, 0, 0)
            return
        }
        // Yaw and pitch near zero mean the face points straight at the lens.
        let signedYaw = face.yaw?.doubleValue ?? 0
        let yaw = abs(face.yaw?.doubleValue ?? 1)
        let pitch = abs(face.pitch?.doubleValue ?? 1)
        let gaze = max(0, 1 - (yaw / 0.6 + pitch / 0.6) / 2)
        onFace?(true, gaze, signedYaw)
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
