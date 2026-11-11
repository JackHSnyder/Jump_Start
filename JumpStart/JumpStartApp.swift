import SwiftUI

@main
struct JumpStartApp: App {
    @StateObject private var model = AlarmStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
