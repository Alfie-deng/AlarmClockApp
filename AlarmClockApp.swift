import SwiftUI
import UserNotifications

final class AlarmNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var alarmManager: AlarmManager?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let alarmId = response.notification.request.content.userInfo["alarmId"] as? String
        Task { @MainActor in
            alarmManager?.triggerChallenge(alarmId: alarmId)
            completionHandler()
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let alarmId = notification.request.content.userInfo["alarmId"] as? String
        Task { @MainActor in
            alarmManager?.triggerChallenge(alarmId: alarmId)
            completionHandler([.banner, .sound])
        }
    }
}

@main
struct AlarmClockApp: App {
    @UIApplicationDelegateAdaptor(AlarmNotificationDelegate.self) private var appDelegate
    @StateObject private var alarmManager = AlarmManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .onAppear {
                    appDelegate.alarmManager = alarmManager
                }
        }
    }
}
