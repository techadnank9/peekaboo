import SwiftUI

@main
struct PeekabooApp: App {
    @State private var model = PeekabooModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
        }
    }
}
