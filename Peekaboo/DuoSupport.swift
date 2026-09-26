import SwiftUI

// iPhone Duo APIs arrive with the iOS 27.1 SDK (Xcode 27.1 beta). Each wrapper
// here uses the real API when it exists, and a plain fallback otherwise, so
// the app builds and runs on every iPhone with one code path.

/// Viewfinder and controls. On iPhone Duo an ArrangementView splits them
/// across the fold when the device is half open, so the top half is the
/// camera and the bottom half is the control deck, like a tabletop camera.
struct DuoArrangement<Primary: View, Secondary: View>: View {
    @ViewBuilder var primary: Primary
    @ViewBuilder var secondary: Secondary

    var body: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            ArrangementView {
                primary
            } secondary: {
                secondary
            }
            .arrangementViewStyle(.split)
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                primary.frame(minWidth: 520)
                secondary.frame(width: 340)
            }
            VStack(spacing: 0) {
                primary.layoutPriority(1)
                secondary.fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    /// Presents `content` on the outer display, which faces the same way as
    /// the rear camera, while this capture interface is onscreen.
    @ViewBuilder
    func subjectDisplay<Content: View>(isEnabled: Binding<Bool>,
                                       onAvailabilityChange: @escaping (Bool) -> Void,
                                       @ViewBuilder content: @escaping () -> Content) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            self.sceneAccessory {
                CameraCaptureAccessory(isEnabled: isEnabled) {
                    content()
                }
                .onAvailabilityChange(perform: onAvailabilityChange)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Reports whether the fold currently divides this view, which happens
    /// when iPhone Duo is partially open, such as standing on a table.
    func onFoldChange(_ action: @escaping (_ isDivided: Bool, _ foldFrame: CGRect?) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                let fold = Self.activeFold(in: proxy)
                Color.clear
                    .onAppear { action(fold != nil, fold) }
                    .onChange(of: fold) { _, new in action(new != nil, new) }
            }
        }
    }

    /// Reports how far down an active camera occlusion reaches into the top
    /// of this view, such as the inner front camera on iPhone Duo.
    func onCameraOcclusionChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                let clearance = Self.topOcclusion(in: proxy)
                Color.clear
                    .onAppear { action(clearance) }
                    .onChange(of: clearance) { _, new in action(new) }
            }
        }
    }

    private static func topOcclusion(in proxy: GeometryProxy) -> CGFloat {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .occlusion)
                .filter { $0.isActive && $0.frame.minY < 80 }
                .map(\.frame.maxY)
                .max() ?? 0
        }
        #endif
        return 0
    }

    private static func activeFold(in proxy: GeometryProxy) -> CGRect? {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division)
                .first(where: \.isActive)?
                .frame
        }
        #endif
        return nil
    }
}
