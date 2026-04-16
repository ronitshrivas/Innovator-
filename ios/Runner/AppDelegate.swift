import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ── 1. Video & Audio Session ─────────────────────────────────────
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AVAudioSession] Error: \(error)")
        }

        // ── 2. Firebase ──────────────────────────────────────────────────
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        // ── 3. Notifications ─────────────────────────────────────────────
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("[Notifications] Permission granted: \(granted)")
        }
        application.registerForRemoteNotifications()

        // ── 4. Flutter ───────────────────────────────────────────────────
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ── APNs token → Firebase ────────────────────────────────────────────
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(
            application,
            didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
        )
    }

    // ── APNs registration failed ─────────────────────────────────────────
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Failed: \(error.localizedDescription)")
    }

    // ── Show notification when app is FOREGROUND ─────────────────────────
    // NOTE: 'override' required because FlutterAppDelegate already implements this
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    // ── Handle notification TAP ──────────────────────────────────────────
    // NOTE: 'override' required because FlutterAppDelegate already implements this
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[Notification] Tapped: \(userInfo)")
        completionHandler()
    }
}

// ── FCM Token — extension is safe here (MessagingDelegate only) ──────────────
extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        print("[FCM] Token: \(fcmToken ?? "nil")")
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: ["token": fcmToken ?? ""]
        )
    }
}