//
//  sevgilimApp.swift
//  sevgilim
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@main
struct sevgilimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - Centralized Dependencies Container
    @StateObject private var dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Core services (always needed)
                .environmentObject(dependencies.authService)
                .environmentObject(dependencies.relationshipService)
                .environmentObject(dependencies.themeManager)
                .environmentObject(dependencies.navigationRouter)
                // Feature services (lazy loaded)
                .environmentObject(dependencies.memoryService)
                .environmentObject(dependencies.photoService)
                .environmentObject(dependencies.noteService)
                .environmentObject(dependencies.movieService)
                .environmentObject(dependencies.planService)
                .environmentObject(dependencies.placeService)
                .environmentObject(dependencies.songService)
                .environmentObject(dependencies.spotifyService)
                .environmentObject(dependencies.surpriseService)
                .environmentObject(dependencies.specialDayService)
                .environmentObject(dependencies.storyService)
                .environmentObject(dependencies.messageService)
                .environmentObject(dependencies.moodService)
                .environmentObject(dependencies.greetingService)
                .environmentObject(dependencies.secretVaultService)
                .onAppear {
                    appDelegate.navigationRouter = dependencies.navigationRouter
                }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    weak var navigationRouter: AppNavigationRouter? {
        didSet {
            guard let router = navigationRouter else { return }
            pendingNavigationActions.forEach { action in
                action(router)
            }
            pendingNavigationActions.removeAll()
        }
    }
    
    private var pendingNavigationActions: [(AppNavigationRouter) -> Void] = []
    
    /// Rozet sayısını saklamak için kullanılacak UserDefaults anahtarı
    private let badgeKey = "badgeCount"
    
    /// Saklanan rozet değerini get/set eden özellik
    private var badgeCount: Int {
        get { UserDefaults.standard.integer(forKey: badgeKey) }
        set { UserDefaults.standard.set(newValue, forKey: badgeKey) }
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Firebase'i yapılandır
        FirebaseApp.configure()
        
        // Bildirim delegelerini ayarla
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Kullanıcıdan bildirim izni iste
        requestNotificationPermissions()
        
        // Uygulamanın önceden kalan rozeti varsa sıfırla
        resetBadge()
        
        // Firebase’e ait token senkronizasyonu yapılacaksa
        PushNotificationManager.shared.refreshIfNeeded()
        
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            routeNotificationIfNeeded(userInfo: remoteNotification)
        }
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        PushNotificationManager.shared.refreshIfNeeded()
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs kayıt hatası: \(error.localizedDescription)")
    }
    
    /// Uygulama aktif olduğunda rozet sıfırlanır ve token senkronizasyonu yapılır.
    func applicationDidBecomeActive(_ application: UIApplication) {
        resetBadge()
        PushNotificationManager.shared.syncTokenWithCurrentUser()
    }
    
    /// Arka plandan dönüldüğünde rozetler ve bildirimler temizlenir.
    func applicationWillEnterForeground(_ application: UIApplication) {
        resetBadge()
    }
    
    /// FCM token güncellendiğinde sunucuya iletilir.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        PushNotificationManager.shared.updateFCMToken(token)
    }
    
    /// Uygulama ön plandayken gelen bildirim için çağrılır.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Bildirimin userInfo’sundan rozet güncellenir
        updateBadge(using: notification.request.content.userInfo)
        
        // Banner, liste ve ses gösterilir. Badge güncellenmesi manuel yapıldığı için .badge eklenmez
        completionHandler([.banner, .list, .sound])
    }
    
    /// Kullanıcı bildirim etkileşimine yanıt verdiğinde çağrılır.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Bildirim açıldığında rozet güncellenir
        updateBadge(using: response.notification.request.content.userInfo)
        
        // Bildirimin içeriğini uygulamanın diğer bölümlerine aktar
        NotificationCenter.default.post(
            name: .didReceiveRemoteNotification,
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
        routeNotificationIfNeeded(userInfo: response.notification.request.content.userInfo)
        
        completionHandler()
    }
    
    /// Bildirim izinlerini ister.
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Bildirim izni hatası: \(error.localizedDescription)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("ℹ️ Kullanıcı bildirim izni vermedi.")
            }
        }
    }
    
    /// Rozet değerini güncelleyen metod. userInfo içinde aps.badge varsa onu kullanır; yoksa +1 artırır.
    private func updateBadge(using userInfo: [AnyHashable: Any]) {
        guard shouldUpdateBadge(for: userInfo) else { return }
        let updateBlock = {
            // Eğer bildirim payload’ı içinde “aps.badge” varsa onu kullan
            if let aps = userInfo["aps"] as? [String: Any],
               let badgeValue = aps["badge"] as? Int {
                self.badgeCount = badgeValue
            } else {
                // Değer gönderilmediyse +1 artır
                self.badgeCount = max(self.badgeCount + 1, 1)
            }
            
            // iOS 17 ve üzeri için setBadgeCount kullanılır; alt sürümlerde eski API
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(self.badgeCount) { error in
                    if let error = error {
                        print("Rozet güncelleme hatası: \(error.localizedDescription)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = self.badgeCount
            }
        }
        
        // Ana thread’de çalıştır; arka plandaysa ana thread’e gönder
        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async {
                updateBlock()
            }
        }
    }
    
    private func shouldUpdateBadge(for userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = notificationType(from: userInfo)?.lowercased() else {
            return false
        }
        return type == "message_new"
    }
    
    private func notificationType(from userInfo: [AnyHashable: Any]) -> String? {
        if let type = userInfo["type"] as? String {
            return type
        }
        if let data = userInfo["data"] as? [String: Any],
           let type = data["type"] as? String {
            return type
        }
        if let type = userInfo["gcm.notification.type"] as? String {
            return type
        }
        if let type = userInfo["gcm.message_type"] as? String {
            return type
        }
        return nil
    }
    
    private func routeNotificationIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let type = notificationType(from: userInfo)?.lowercased() else { return }
        switch type {
        case "message_new":
            enqueueNavigation { $0.openChat() }
        case "surprise_new":
            enqueueNavigation { $0.openSurprises() }
        case "special_day_upcoming":
            enqueueNavigation { $0.openSpecialDays() }
        case "plan_reminder":
            enqueueNavigation { $0.openPlans() }
        case "movie_night":
            enqueueNavigation { $0.openMovies() }
        case "note_shared":
            enqueueNavigation { $0.openNotes() }
        case "photo_added":
            enqueueNavigation { $0.openPhotos() }
        case "song_shared":
            enqueueNavigation { $0.openSongs() }
        case "place_recommendation":
            enqueueNavigation { $0.openPlaces() }
        case "secret_vault_alert":
            enqueueNavigation { $0.openSecretVault() }
        case "memory_new":
            enqueueNavigation { $0.openMemories() }
        case "meeting_started", "meeting_notification":
            enqueueNavigation { $0.openLocation() }
        default:
            break
        }
    }
    
    private func enqueueNavigation(_ action: @escaping (AppNavigationRouter) -> Void) {
        if let router = navigationRouter {
            action(router)
        } else {
            pendingNavigationActions.append(action)
        }
    }
    
    /// Rozet ve bildirimleri sıfırlar.
    private func resetBadge() {
        let clearBlock = {
            // Yerel saklanan badge sayısını sıfırla
            self.badgeCount = 0
            
            // iOS 17 ve üzeri için setBadgeCount ile sıfırla
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0) { error in
                    if let error = error {
                        print("Rozet sıfırlama hatası: \(error.localizedDescription)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            
            // Bildirim Merkezi’ndeki bildirimleri temizle
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        
        if Thread.isMainThread {
            clearBlock()
        } else {
            DispatchQueue.main.async {
                clearBlock()
            }
        }
    }
}

// Bildirim geldiğinde kullanılacak notification name
extension Notification.Name {
    static let didReceiveRemoteNotification = Notification.Name("didReceiveRemoteNotification")
}
