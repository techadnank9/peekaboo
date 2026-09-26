import AVFoundation
import AVKit
import SwiftUI

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    /// Keeps the direction coordinator alive while the preview is onscreen.
    var directionObserver: AnyObject?
}

/// The live viewfinder. On iPhone Duo it also watches which way each camera
/// faces, so Peekaboo always shoots from a camera pointing at the subject,
/// the same side the outer display faces.
struct CameraPreview: UIViewRepresentable {
    let camera: CameraService

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.directionObserver = SubjectCameraTracker.make(previewView: view, camera: camera)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

enum SubjectCameraTracker {
    @MainActor
    static func make(previewView: UIView, camera: CameraService) -> AnyObject? {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            // Cameras that face away from the photographer's view face the
            // subject. On iPhone Duo that set changes as the device opens,
            // closes and rotates, so follow it instead of trusting `position`.
            let coordinator = AVCaptureDeviceDirectionCoordinator(
                view: previewView,
                deviceTypes: [
                    .builtInWideAngleCamera,
                    .builtInDualWideCamera,
                    .builtInOuterUltraWideCamera,
                    .builtInInnerUltraWideCamera,
                ]
            ) { directions in
                let subjectFacing = directions.backwardFacingDeviceDescriptors
                // Prefer the main rear camera for image quality.
                let best = subjectFacing.first { $0.deviceType == .builtInWideAngleCamera }
                    ?? subjectFacing.first { $0.deviceType == .builtInDualWideCamera }
                    ?? subjectFacing.first
                if let best { camera.selectCamera(uniqueID: best.uniqueID) }
            }
            return coordinator
        }
        #endif
        return nil
    }
}
