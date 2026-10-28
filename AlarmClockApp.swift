import SwiftUI

@main
struct AlarmClockApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var alarmManager = AlarmManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .onAppear {
                    RefreshRateProbe.startIfRequested()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            alarmManager.isAppActive = phase == .active
            guard phase == .active else { return }
            Task { await alarmManager.syncSystemAlarms() }
        }
    }
}
